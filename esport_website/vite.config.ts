import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'Esport Adda',
        short_name: 'Esport Adda',
        description: 'The Ultimate Platform to Dominate Esport - Join tournaments, win real prizes',
        start_url: '/',
        display: 'standalone',
        background_color: '#020617',
        theme_color: '#6366f1',
        icons: [
          { src: '/vite.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' }
        ]
      }
    })
  ]
})
