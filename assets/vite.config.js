export default {
     publicDir: "./static",
      build: {
        target: "es2018",
        minify: true,
        outDir: "../priv/static",
        emptyOutDir: true,
        rollupOptions: {
          input: ["js/app.js", "css/app.scss"],
          output: {
            entryFileNames: "js/[name].js",
            chunkFileNames: "js/[name].js",
            assetFileNames: "[ext]/[name][extname]"
          }
        },
        assetsInlineLimit: 0
      }
    }
    