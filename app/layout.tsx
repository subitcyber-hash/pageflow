import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title:       "PageFlow — Facebook Automation",
  description: "AI-powered Facebook automation for businesses. Auto-reply, capture leads, and grow sales.",
  manifest:    "/manifest.json",
  appleWebApp: {
    capable:        true,
    statusBarStyle: "black-translucent",
    title:          "PageFlow",
  },
  formatDetection: { telephone: false },
  openGraph: {
    title:       "PageFlow",
    description: "AI-powered Facebook automation",
    type:        "website",
  },
};

export const viewport: Viewport = {
  width:              "device-width",
  initialScale:       1,
  maximumScale:       1,
  userScalable:       false,
  themeColor:         "#6366f1",
  viewportFit:        "cover",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,300&family=Syne:wght@600;700;800&display=swap"
          rel="stylesheet"
        />

        {/* PWA Icons */}
        <link rel="icon"             href="/icons/icon-192.png" />
        <link rel="apple-touch-icon" href="/icons/icon-192.png" />
        <link rel="apple-touch-icon" sizes="152x152" href="/icons/icon-152.png" />
        <link rel="apple-touch-icon" sizes="144x144" href="/icons/icon-144.png" />

        {/* iOS PWA splash screen color */}
        <meta name="apple-mobile-web-app-capable"          content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="mobile-web-app-capable"                content="yes" />

        {/* Register service worker */}
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', function() {
                  navigator.serviceWorker.register('/sw.js').then(function(reg) {
                    console.log('[PWA] Service worker registered:', reg.scope);
                  }).catch(function(err) {
                    console.log('[PWA] Service worker failed:', err);
                  });
                });
              }
            `,
          }}
        />
      </head>
      <body className="bg-[#0a0a0f] text-zinc-100 antialiased font-sans">
        {children}
      </body>
    </html>
  );
}