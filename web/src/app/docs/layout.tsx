export default function DocsLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        <div className="container" style={{ display: 'grid', gridTemplateColumns: '250px 1fr', gap: '60px', marginTop: '60px' }}>
            <aside style={{ position: 'sticky', top: '120px', height: 'fit-content' }}>
                <h4 style={{ marginBottom: '20px', color: 'var(--accent-color)' }}>Getting Started</h4>
                <nav style={{ display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '0.95rem' }}>
                    <a href="/docs" className="text-hover" style={{ fontWeight: 600 }}>Introduction</a>
                    <a href="/docs/installation" className="text-hover">Installation</a>
                    <a href="/docs/scanning" className="text-hover">Scanning Library</a>
                </nav>

                <h4 style={{ marginTop: '40px', marginBottom: '20px', color: 'var(--accent-color)' }}>Features</h4>
                <nav style={{ display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '0.95rem' }}>
                    <a href="/docs/fingerprinting" className="text-hover">Audio Fingerprinting</a>
                    <a href="/docs/auto-fix" className="text-hover">Auto-Fix Metadata</a>
                    <a href="/docs/flac-support" className="text-hover">FLAC Support</a>
                </nav>
            </aside>
            <article style={{ maxWidth: '800px' }}>
                {children}
            </article>
        </div>
    );
}
