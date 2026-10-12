import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "BusNow!!",
    short_name: "BusNow!!",
    description: "富士見台と溝の口駅南口のあいだだけを映す停留所の看板。",
    start_url: "/",
    display: "standalone",
    background_color: "#241c16",
    theme_color: "#241c16",
    lang: "ja",
    icons: [
      { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
