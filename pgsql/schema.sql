-- Boardify SQL Schema
-- This schema is designed for a multi-tenant, collaborative task management app.
-- RLS (Row-Level Security) is enabled and configured for all tables.

-- 1. Create custom types (enums) for clarity and data integrity.
CREATE TYPE subscription_plan AS ENUM ('free', 'pro');
CREATE TYPE board_role AS ENUM ('admin', 'editor', 'viewer');
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high');

-- 2. Create the 'users' table.
-- Stores user-specific information, linked to their Telegram ID.
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telegram_id BIGINT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    subscription subscription_plan NOT NULL DEFAULT 'free',
    pro_expiry_date TIMESTAMPTZ
);

-- 3. Create the 'boards' table.
-- Each board is a top-level container for tasks.
CREATE TABLE boards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Create the 'board_members' table (join table).
-- Manages user access and permissions for each board.
CREATE TABLE board_members (
    board_id UUID NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role board_role NOT NULL DEFAULT 'editor',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (board_id, user_id)
);

-- 5. Create the 'statuses' table.
-- Represents the columns on a Kanban board (e.g., "To Do", "In Progress").
CREATE TABLE statuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    position INT NOT NULL, -- For ordering columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Create the 'tasks' table.
-- Represents a single task card ("brick").
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority task_priority NOT NULL DEFAULT 'medium',
    due_date DATE,
    position INT NOT NULL, -- For ordering tasks within a status column
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Create the 'task_assignees' table (join table).
-- Links users to specific tasks they are assigned to.
CREATE TABLE task_assignees (
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, user_id)
);

-- 8. Create the 'referrals' table.
-- Tracks user referrals for the growth mechanic.
CREATE TABLE referrals (
    id BIGSERIAL PRIMARY KEY,
    referrer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    new_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (referrer_id, new_user_id)
);

-- 9. SETUP ROW-LEVEL SECURITY (RLS) -- THIS IS CRUCIAL FOR SECURITY.

-- Helper function to get the current authenticated user's ID
CREATE OR REPLACE FUNCTION auth.get_user_id()
RETURNS UUID AS $$
BEGIN
  RETURN auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS for all relevant tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE board_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignees ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- RLS Policies for 'users'
CREATE POLICY "Users can view and edit their own data"
    ON users FOR ALL
    USING (id = auth.get_user_id())
    WITH CHECK (id = auth.get_user_id());

-- RLS Policies for 'boards'
CREATE POLICY "Users can view boards they are members of"
    ON boards FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM board_members
        WHERE board_members.board_id = boards.id AND board_members.user_id = auth.get_user_id()
    ));

CREATE POLICY "Board admins can update their boards"
    ON boards FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM board_members
        WHERE board_members.board_id = boards.id
        AND board_members.user_id = auth.get_user_id()
        AND board_members.role = 'admin'
    ));

CREATE POLICY "Users can create new boards"
    ON boards FOR INSERT
    WITH CHECK (true); -- Further checks will be handled in app logic/triggers

-- RLS Policies for 'board_members'
CREATE POLICY "Users can view memberships of boards they belong to"
    ON board_members FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM board_members bm
        WHERE bm.board_id = board_members.board_id AND bm.user_id = auth.get_user_id()
    ));

CREATE POLICY "Board admins can manage members"
    ON board_members FOR ALL
    USING (EXISTS (
        SELECT 1 FROM board_members bm
        WHERE bm.board_id = board_members.board_id
        AND bm.user_id = auth.get_user_id()
        AND bm.role = 'admin'
    ));

-- RLS Policies for 'statuses' and 'tasks'
-- The logic is the same: you can access the item if you can access the parent board.
CREATE POLICY "Users can view statuses of boards they are members of"
    ON statuses FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM board_members
        WHERE board_members.board_id = statuses.board_id AND board_members.user_id = auth.get_user_id()
    ));
CREATE POLICY "Board editors/admins can manage statuses"
    ON statuses FOR ALL
    USING (EXISTS (
        SELECT 1 FROM board_members
        WHERE board_members.board_id = statuses.board_id
        AND board_members.user_id = auth.get_user_id()
        AND (board_members.role = 'admin' OR board_members.role = 'editor')
    ));

CREATE POLICY "Users can view tasks of boards they are members of"
    ON tasks FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM board_members
        WHERE board_members.board_id = tasks.board_id AND board_members.user_id = auth.get_user_id()
    ));
CREATE POLICY "Board editors/admins can manage tasks"
    ON tasks FOR ALL
    USING (EXISTS (
        SELECT 1 FROM board_members
        WHERE board_members.board_id = tasks.board_id
        AND board_members.user_id = auth.get_user_id()
        AND (board_members.role = 'admin' OR board_members.role = 'editor')
    ));

-- RLS Policies for other tables can be added as needed (e.g., task_assignees)
CREATE POLICY "Users can manage task assignees on boards they can edit"
    ON task_assignees FOR ALL
    USING (EXISTS (
        SELECT 1
        FROM tasks t
        JOIN board_members bm ON t.board_id = bm.board_id
        WHERE t.id = task_assignees.task_id
        AND bm.user_id = auth.get_user_id()
        AND (bm.role = 'admin' OR bm.role = 'editor')
    ));