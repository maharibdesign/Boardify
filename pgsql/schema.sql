-- Boardify SQL Schema (Version 3.1 - Final)

-- 1. Create custom types (enums)
CREATE TYPE public.subscription_plan AS ENUM ('free', 'pro');
CREATE TYPE public.board_role AS ENUM ('admin', 'editor', 'viewer');
CREATE TYPE public.task_priority AS ENUM ('low', 'medium', 'high');

-- 2. Create the 'users' table.
-- This table stores public profile information.
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- This links to the Supabase auth user.
    auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    telegram_id BIGINT UNIQUE,
    username VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    subscription public.subscription_plan NOT NULL DEFAULT 'free',
    pro_expiry_date TIMESTAMPTZ
);

-- 3. Create the 'boards' table.
CREATE TABLE public.boards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Create the 'board_members' table (join table).
CREATE TABLE public.board_members (
    board_id UUID NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role public.board_role NOT NULL DEFAULT 'editor',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (board_id, user_id)
);

-- 5. Create the 'statuses' table.
CREATE TABLE public.statuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    position INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Create the 'tasks' table.
CREATE TABLE public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    status_id UUID NOT NULL REFERENCES public.statuses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority public.task_priority NOT NULL DEFAULT 'medium',
    due_date DATE,
    position INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Create 'task_assignees' table
CREATE TABLE public.task_assignees (
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, user_id)
);

-- 8. Create 'referrals' table
CREATE TABLE public.referrals (
    id BIGSERIAL PRIMARY KEY,
    referrer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    new_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (referrer_id, new_user_id)
);


-- 9. SETUP AUTH TRIGGERS AND ROW-LEVEL SECURITY (RLS)

-- Helper function to get our app-specific user ID from the Supabase auth ID.
CREATE OR REPLACE FUNCTION public.get_user_app_id()
RETURNS UUID AS $$
DECLARE
  app_user_id UUID;
BEGIN
  SELECT id INTO app_user_id FROM public.users WHERE auth_id = auth.uid() LIMIT 1;
  RETURN app_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- This trigger automatically creates a user profile entry when a new user signs up.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (auth_id, username)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if the trigger exists before creating it to avoid errors on re-runs
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
  END IF;
END $$;


-- Enable RLS for all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;


-- RLS POLICIES

-- USERS: Users can see their own profile and update it.
CREATE POLICY "Users can view and update their own profile" ON public.users
  FOR ALL USING (auth_id = auth.uid());

-- BOARDS:
CREATE POLICY "Users can view boards they are members of" ON public.boards
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.board_members
    WHERE board_members.board_id = boards.id AND board_members.user_id = public.get_user_app_id()
  ));

CREATE POLICY "Users can insert boards for themselves" ON public.boards
  FOR INSERT WITH CHECK (owner_id = public.get_user_app_id());

CREATE POLICY "Board admins can update their boards" ON public.boards
  FOR UPDATE USING (EXISTS (
    SELECT 1 FROM public.board_members
    WHERE board_members.board_id = boards.id AND board_members.user_id = public.get_user_app_id() AND board_members.role = 'admin'
  )) WITH CHECK (EXISTS (
    SELECT 1 FROM public.board_members
    WHERE board_members.board_id = boards.id AND board_members.user_id = public.get_user_app_id() AND board_members.role = 'admin'
  ));

CREATE POLICY "Board admins can delete their boards" ON public.boards
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.board_members
    WHERE board_members.board_id = boards.id AND board_members.user_id = public.get_user_app_id() AND board_members.role = 'admin'
  ));

-- BOARD_MEMBERS:
CREATE POLICY "Users can view memberships of boards they belong to" ON public.board_members
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.board_members bm
    WHERE bm.board_id = board_members.board_id AND bm.user_id = public.get_user_app_id()
  ));

CREATE POLICY "Board admins can manage members" ON public.board_members
  FOR ALL USING (EXISTS (
    SELECT 1 FROM public.board_members bm
    WHERE bm.board_id = board_members.board_id AND bm.user_id = public.get_user_app_id() AND bm.role = 'admin'
  ));

-- STATUSES, TASKS, etc.
CREATE POLICY "Users can manage items on boards they are members of" ON public.statuses
  FOR ALL USING (EXISTS (
    SELECT 1 FROM public.board_members
    WHERE board_members.board_id = statuses.board_id AND board_members.user_id = public.get_user_app_id()
  ));

CREATE POLICY "Users can manage items on boards they are members of" ON public.tasks
  FOR ALL USING (EXISTS (
    SELECT 1 FROM public.board_members
    WHERE board_members.board_id = tasks.board_id AND board_members.user_id = public.get_user_app_id()
  ));

CREATE POLICY "Users can manage items on boards they are members of" ON public.task_assignees
  FOR ALL USING (EXISTS (
    SELECT 1 FROM tasks t JOIN board_members bm ON t.board_id = bm.board_id
    WHERE t.id = task_assignees.task_id AND bm.user_id = public.get_user_app_id()
  ));