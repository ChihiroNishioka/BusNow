import type { Metadata, Viewport } from "next";
import { Noto_Sans_JP } from "next/font/google";
import { ServiceWorkerRegister } from "@/components/sw-register";
import "./globals.css";

export const runtime = "nodejs";

const noto = Noto_Sans_JP({
  subsets: ["latin"],
  weight: ["500", "700", "900"],
  variable: "--font-noto",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "BusNow!!",
    template: "%s · BusNow!!",
  },
  description: "富士見台と溝の口駅南口のあいだだけを映す停留所の看板。",
  applicationName: "BusNow!!",
  appleWebApp: {
    capable: true,
    title: "BusNow!!",
    statusBarStyle: "black-translucent",
  },
  formatDetection: {
    telephone: false,
  },
  other: {
    "apple-mobile-web-app-capable": "yes",
  },
  icons: {
    icon: [{ url: "/icon-192.png", sizes: "192x192", type: "image/png" }],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#241c16",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ja" className={`${noto.variable} h-full antialiased`}>
      <body className="min-h-full">
        {children}
        <ServiceWorkerRegister />
      </body>
    </html>
  );
}
