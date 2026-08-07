import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icon.svg", "light-pigment-background.png"],
      manifest: {
        name: "Memory Hub",
        short_name: "Memory Hub",
        description: "个人记忆与生活信息管理",
        lang: "zh-CN",
        start_url: "/",
        display: "standalone",
        background_color: "#F6F8FC",
        theme_color: "#F6F8FC",
        icons: [
          { src: "/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any maskable" }
        ]
      },
      workbox: {
        navigateFallback: "/index.html",
        globPatterns: ["**/*.{js,css,html,svg,png}"],
        maximumFileSizeToCacheInBytes: 3 * 1024 * 1024
      }
    })
  ]
});
