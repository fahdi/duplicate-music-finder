import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Duplicate Music Finder | Clean Your Music Library with Audio Fingerprinting",
  description: "The ultimate macOS app to find and remove duplicate songs. Uses advanced audio fingerprinting to detect identical tracks regardless of format or bitrate.",
  keywords: "duplicate music finder, music library cleaner, macOS music app, audio fingerprinting, clean itunes library, flac metadata fixer",
  openGraph: {
    title: "Duplicate Music Finder | Clean Your Music Library",
    description: "Find and remove duplicate songs with high precision using audio fingerprinting.",
    type: "website",
    locale: "en_US",
    url: "https://duplicatemusicfinder.com",
    siteName: "Duplicate Music Finder",
  },
  twitter: {
    card: "summary_large_image",
    title: "Duplicate Music Finder",
    description: "The ultimate tool for cleaning your music library on macOS.",
  },
  robots: {
    index: true,
    follow: true,
  }
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <nav className="glass container" style={{
          marginTop: '20px',
          height: '70px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 30px',
          position: 'sticky',
          top: '20px',
          zIndex: 1000
        }}>
          <div style={{ fontWeight: 800, fontSize: '1.2rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <span style={{ color: 'var(--accent-color)' }}>◉</span> Duplicate Music Finder
          </div>
          <div style={{ display: 'flex', gap: '30px', fontWeight: 500, fontSize: '0.9rem' }}>
            <a href="/" className="text-hover">Home</a>
            <a href="/docs" className="text-hover">Documentation</a>
            <a href="/#pricing" className="text-hover">Pricing</a>
          </div>
          <a href="/download" className="btn btn-primary" style={{ padding: '8px 20px', fontSize: '0.85rem' }}>
            Download Free
          </a>
        </nav>
        {children}
        <footer className="section" style={{ borderTop: '1px solid var(--border-color)', marginTop: '60px' }}>
          <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="text-muted" style={{ fontSize: '0.9rem' }}>
              &copy; 2025 Duplicate Music Finder. All rights reserved.
            </div>
            <div style={{ display: 'flex', gap: '20px' }}>
              <a href="/privacy" className="text-muted">Privacy</a>
              <a href="/terms" className="text-muted">Terms</a>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
