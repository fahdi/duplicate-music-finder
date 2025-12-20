export default function Home() {
  return (
    <main>
      {/* Hero Section */}
      <section className="section" style={{ textAlign: 'center', position: 'relative', overflow: 'hidden' }}>
        <div style={{
          position: 'absolute',
          top: '-10%',
          left: '50%',
          width: '80%',
          height: '600px',
          background: 'radial-gradient(circle, rgba(251, 191, 36, 0.05) 0%, transparent 70%)',
          filter: 'blur(100px)',
          transform: 'translateX(-50%)',
          zIndex: -1
        }}></div>

        <div className="container fade-in">
          <h1 className="title-large">
            Clean your <span className="title-accent">Music Library</span><br />
            with bit-perfect accuracy.
          </h1>
          <p className="text-muted" style={{ fontSize: '1.25rem', maxWidth: '700px', margin: '30px auto', fontWeight: 400 }}>
            Duplicate Music Finder uses advanced audio fingerprinting to identify identical tracks,
            even if they have different formats or bitrates.
          </p>
          <div style={{ display: 'flex', gap: '20px', justifyContent: 'center', marginTop: '40px' }}>
            <a href="/download" className="btn btn-primary" style={{ padding: '16px 40px', fontSize: '1.1rem' }}>
              Download for macOS
            </a>
            <a href="/docs" className="btn btn-outline" style={{ padding: '16px 40px', fontSize: '1.1rem' }}>
              View Documentation
            </a>
          </div>

          <div className="glass" style={{
            marginTop: '80px',
            height: '400px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '0.9rem',
            color: 'var(--text-muted)',
            position: 'relative',
            overflow: 'hidden'
          }}>
            {/* Mockup visual placeholder */}
            <div style={{ padding: '40px', textAlign: 'left', width: '100%' }}>
              <div style={{ display: 'flex', gap: '20px', marginBottom: '30px' }}>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#ff5f56' }}></div>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#ffbd2e' }}></div>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#27c93f' }}></div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '40px' }}>
                <div className="glass" style={{ padding: '20px', border: '1px solid var(--accent-color)' }}>
                  <div style={{ fontWeight: 600, color: '#fff', marginBottom: '10px' }}>Track A (Original)</div>
                  <div style={{ fontSize: '0.8rem' }}>Format: FLAC (Lossless)</div>
                  <div style={{ fontSize: '0.8rem' }}>Bitrate: 942 kbps</div>
                  <div style={{ marginTop: '15px', height: '4px', width: '100%', background: 'rgba(255,255,255,0.1)', borderRadius: '2px' }}>
                    <div style={{ height: '100%', width: '85%', background: 'var(--accent-color)', borderRadius: '2px' }}></div>
                  </div>
                </div>
                <div className="glass" style={{ padding: '20px', border: '1px solid rgba(255,255,255,0.2)' }}>
                  <div style={{ fontWeight: 600, color: '#fff', marginBottom: '10px' }}>Track B (Duplicate)</div>
                  <div style={{ fontSize: '0.8rem' }}>Format: MP3</div>
                  <div style={{ fontSize: '0.8rem' }}>Bitrate: 128 kbps</div>
                  <div style={{ marginTop: '15px', height: '4px', width: '100%', background: 'rgba(255,255,255,0.1)', borderRadius: '2px' }}>
                    <div style={{ height: '100%', width: '85%', background: '#ef4444', borderRadius: '2px' }}></div>
                  </div>
                </div>
              </div>
              <div style={{ marginTop: '30px', textAlign: 'center', color: 'var(--accent-color)', fontWeight: 600 }}>
                99.8% Audio Match Detected
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="section container" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '30px' }}>
        <div className="glass" style={{ padding: '40px' }}>
          <div style={{ fontSize: '2rem', marginBottom: '20px' }}>🎧</div>
          <h3 style={{ marginBottom: '15px' }}>Audio Fingerprinting</h3>
          <p className="text-muted">Unlike basic apps, we analyze the actual sound waves to find matches regardless of filename or metadata.</p>
        </div>
        <div className="glass" style={{ padding: '40px' }}>
          <div style={{ fontSize: '2rem', marginBottom: '20px' }}>🏷️</div>
          <h3 style={{ marginBottom: '15px' }}>Smart Tag Fixer</h3>
          <p className="text-muted">Automatically identify songs and download missing artwork and metadata via AcoustID and MusicBrainz.</p>
        </div>
        <div className="glass" style={{ padding: '40px' }}>
          <div style={{ fontSize: '2rem', marginBottom: '20px' }}>💎</div>
          <h3 style={{ marginBottom: '15px' }}>FLAC & Lossless</h3>
          <p className="text-muted">First-class support for audiophile formats. Safely update metadata for FLAC, ALAC, and AIFF files.</p>
        </div>
      </section>

      {/* CTA Section */}
      <section className="section" style={{ background: 'rgba(251, 191, 36, 0.02)', borderTop: '1px solid var(--border-color)' }}>
        <div className="container" style={{ textAlign: 'center' }}>
          <h2 className="title-medium">Ready to reclaim your disk space?</h2>
          <p className="text-muted" style={{ margin: '20px 0 40px' }}>Get started with the fastest music duplicate finder on the market.</p>
          <a href="/download" className="btn btn-primary" style={{ padding: '16px 60px' }}>
            Get Trial Version
          </a>
        </div>
      </section>
    </main>
  );
}
