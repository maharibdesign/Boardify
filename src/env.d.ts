/// <reference path="../.astro/types.d.ts" />
interface ImportMetaEnv {
  readonly PASSWORD: string;
  readonly PUBLIC_SUPABASE_URL: string;
  readonly PUBLIC_SUPABASE_ANON_KEY: string;
  readonly PUBLIC_TWA_ANALYTICS_KEY: string;
  readonly TELEGRAM_BOT_TOKEN: string;
  readonly VERCEL_URL: string;

  // more env variables...
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}