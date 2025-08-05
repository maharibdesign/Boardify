# Boardify - The Ultimate Task Management Mini App for Telegram

Boardify is a feature-rich, Trello-inspired task management Mini App built for superior user experience, retention, and monetization. It is built using the Astro, Supabase, and Vercel stack.

## Getting Started

Follow these instructions to set up your development environment.

### 1. Supabase Project Setup

Supabase will be our all-in-one backend for database, real-time updates, and authentication.

1.  **Create a Supabase Project:**
    *   Go to [supabase.com](https://supabase.com) and create a new project.
    *   Choose a strong database password and save it securely.

2.  **Get API Keys:**
    *   In your Supabase project dashboard, navigate to **Project Settings > API**.
    *   You will find your **Project URL** and the `public` **anon key**. You will need these for your environment variables.

3.  **Run the Database Schema:**
    *   Go to the **SQL Editor** in your Supabase dashboard.
    *   Click **+ New query**.
    *   Copy the entire content of the `pgsql/schema.sql` file from this repository and paste it into the query editor.
    *   Click **RUN**. This will create all your tables, types, and security policies.

4.  **Enable Realtime:**
    *   Go to **Database > Replication**.
    *   Under "Source", click on the "0 tables" link.
    *   Click the "Enable Realtime" toggle for all tables you want to broadcast changes for (e.g., `tasks`, `statuses`). This is crucial for live collaboration.

### 2. Local Development Setup

1.  **Clone the Repository:**
    ```bash
    git clone <your-repository-url>
    cd Boardify
    ```

2.  **Install Dependencies:**
    ```bash
    npm install
    ```

3.  **Set Up Environment Variables:**
    *   Create a new file named `.env` in the root of the project. You can do this by copying the example file:
      ```bash
      cp .env.example .env
      ```
    *   Open the `.env` file and fill in the values you got from Supabase:
      ```
      PUBLIC_SUPABASE_URL="YOUR_SUPABASE_URL"
      PUBLIC_SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
      PUBLIC_TWA_ANALYTICS_KEY="YOUR_TELEGRAM_ANALYTICS_KEY" # Optional for now
      ```
    *   **Note:** The `PUBLIC_` prefix is an Astro convention to expose these variables to the client-side browser, which is necessary for the Supabase JS client.

4.  **Run the Development Server:**
    ```bash
    npm run dev
    ```
    Your Boardify app is now running locally, typically at `http://localhost:4321`.

---

*(More sections on Deployment and Telegram Bot setup will be added later)*