export default function DocsPage() {
    return (
        <div className="fade-in">
            <h1 className="title-medium" style={{ marginBottom: '24px' }}>Introduction</h1>
            <p style={{ fontSize: '1.1rem', marginBottom: '30px' }} className="text-muted">
                Duplicate Music Finder is the world's most precise tool for cleaning up messy music libraries on macOS.
                Whether you have thousands of tracks in Apple Music or a curated collection of FLAC files,
                our advanced spectral analysis ensures you find every single duplicate.
            </p>

            <h2 style={{ fontSize: '1.5rem', marginBottom: '20px', marginTop: '40px' }}>Why Duplicate Music Finder?</h2>
            <div style={{ display: 'grid', gap: '24px' }}>
                <div className="glass" style={{ padding: '24px' }}>
                    <h4 style={{ marginBottom: '10px' }}>Beyond Filenames</h4>
                    <p className="text-muted">Most apps only check filenames or sizes. We "listen" to the music using Chromaprint technology to find matches even between an MP3 and a FLAC version of the same song.</p>
                </div>
                <div className="glass" style={{ padding: '24px' }}>
                    <h4 style={{ marginBottom: '10px' }}>Lossless & FLAC Support</h4>
                    <p className="text-muted">Designed for audiophiles. We support writing metadata to FLAC, M4A, and MP3 without re-encoding the audio stream, keeping your music 100% bit-perfect.</p>
                </div>
                <div className="glass" style={{ padding: '24px' }}>
                    <h4 style={{ marginBottom: '10px' }}>Privacy First</h4>
                    <p className="text-muted">Everything happens locally on your Mac. No data is sent to our servers, and we never touch your files without your explicit permission.</p>
                </div>
            </div>

            <div style={{ marginTop: '60px', padding: '30px', background: 'rgba(251, 191, 36, 0.05)', borderRadius: '16px', borderLeft: '4px solid var(--accent-color)' }}>
                <h4 style={{ marginBottom: '10px' }}>Next Step</h4>
                <p className="text-muted">Ready to start? Head over to the <a href="/docs/installation" style={{ color: 'var(--accent-color)', fontWeight: 600 }}>Installation Guide</a> to get set up.</p>
            </div>
        </div>
    );
}
