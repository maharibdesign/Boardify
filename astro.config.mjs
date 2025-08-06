import { defineConfig } from 'astro/config';
import tailwind from "@astrojs/tailwind";
import vercel from "@astrojs/vercel/serverless";

// https://astro.build/config
export default defineConfig({
  output: "server",
  adapter: vercel({
    // This is the crucial new configuration.
    // It tells the adapter to build for the Node.js 20 runtime.
    imageService: true, // You had this, lets keep it
    webAnalytics: { enabled: true }
  }),
  integrations: [tailwind()],
});