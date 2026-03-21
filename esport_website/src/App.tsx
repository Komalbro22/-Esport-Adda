import React, { useEffect, useState } from 'react';
import { HelmetProvider } from 'react-helmet-async';
import { supabase } from './supabase';
import { Download, Zap, Trophy, Shield, Users, Instagram, Send, Mail, ArrowLeft, Lock, CreditCard, CheckCircle2, Star, Smartphone } from 'lucide-react';
import { motion } from 'framer-motion';
import { BrowserRouter as Router, Routes, Route, Link, useParams, useLocation } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
import { TournamentsPage } from './pages/TournamentsPage';
import { BlogPage } from './pages/BlogPage';
import { BlogPostPage } from './pages/BlogPostPage';
import { SeoHead } from './components/SeoHead';
import './App.css';

interface WebSettings {
  contact_info: {
    email: string;
    whatsapp: string;
    instagram: string;
  };
  apk_links: {
    user_app: string;
    admin_app: string;
    user_version: string;
  };
  app_stats: {
    active_players: string;
    live_matches: string;
    total_tournaments: string;
    prize_distributed: string;
  };
}

const Navbar: React.FC<{ userAppUrl?: string }> = ({ userAppUrl }) => (
  <nav className="navbar">
    <Link to="/" className="logo">ESPORT ADDA</Link>
    <div className="nav-actions">
      <Link to="/tournaments" className="nav-link">Tournaments</Link>
      <Link to="/blog" className="nav-link">Blog</Link>
      <a href={userAppUrl ?? '#'} className="btn-primary nav-download" style={!userAppUrl ? { opacity: 0.7, pointerEvents: 'none' } : undefined}>
        Download App
      </a>
    </div>
  </nav>
);

const Footer: React.FC<{ settings: WebSettings | null }> = ({ settings }) => (
  <footer>
    <div className="footer-content">
      <div>
        <div className="logo" style={{ marginBottom: '1rem' }}>ESPORT ADDA</div>
        <p style={{ color: 'var(--text-muted)', maxWidth: '300px' }}>
          India&apos;s trusted esport platform. Secure payments • Instant withdrawals • Fair play guaranteed.
        </p>
        <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem', alignItems: 'center' }}>
          <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}><Lock size={12} style={{ verticalAlign: 'middle', marginRight: 4 }} />Secure</span>
          <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}><Shield size={12} style={{ verticalAlign: 'middle', marginRight: 4 }} />Verified</span>
        </div>
      </div>

      <div className="footer-links-group">
        <h4 style={{ marginBottom: '1rem', color: 'white' }}>Explore</h4>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          <Link to="/tournaments" className="footer-link">Tournaments</Link>
          <Link to="/blog" className="footer-link">Blog</Link>
        </div>
      </div>
      <div className="footer-links-group">
        <h4 style={{ marginBottom: '1rem', color: 'white' }}>Legal</h4>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          <Link to="/legal/privacy_policy" className="footer-link">Privacy Policy</Link>
          <Link to="/legal/terms_and_conditions" className="footer-link">Terms & Conditions</Link>
          <Link to="/legal/refund_policy" className="footer-link">Refund Policy</Link>
        </div>
      </div>

      <div className="footer-links">
        {settings?.contact_info?.instagram && (
          <a href={settings.contact_info.instagram} className="footer-link"><Instagram size={20} /></a>
        )}
        {settings?.contact_info?.whatsapp && (
          <a href={`https://wa.me/${settings.contact_info.whatsapp}`} className="footer-link"><Send size={20} /></a>
        )}
        {settings?.contact_info?.email && (
          <a href={`mailto:${settings.contact_info.email}`} className="footer-link"><Mail size={20} /></a>
        )}
      </div>
    </div>

    <div style={{ textAlign: 'center', marginTop: '3rem', color: 'var(--text-muted)', fontSize: '0.8rem' }}>
      © 2026 Esport Adda. All rights reserved.
    </div>
  </footer>
);

const Home: React.FC<{ settings: WebSettings | null }> = ({ settings }) => {
  const fadeInUp = { initial: { opacity: 0, y: 20 }, animate: { opacity: 1, y: 0 }, transition: { duration: 0.6 } };
  const appUrl = settings?.apk_links?.user_app;
  const hasAppUrl = !!appUrl;

  return (
    <>
      <SeoHead />
      {/* Hero */}
      <header className="hero">
        <motion.div {...fadeInUp} className="hero-content">
          <div className="badge">Trusted by {settings?.app_stats?.active_players || '50K+'} gamers • 100% secure</div>
          <h1>Turn Your Gaming Skills Into <span>Real Money</span></h1>
          <p>India&apos;s #1 esport platform. Join daily tournaments in BGMI, Free Fire & more. Fast payouts via UPI. Start winning today.</p>
          <div className="cta-group hero-cta">
            <a href={appUrl ?? '#'} className="btn-primary btn-download" style={!hasAppUrl ? { opacity: 0.7, pointerEvents: 'none' } : undefined}>
              <Download size={22} /> Download Free App
            </a>
            <Link to="/tournaments" className="btn-secondary">Browse Tournaments</Link>
          </div>
          <div className="trust-badges">
            <span><Lock size={14} /> Secure Payments</span>
            <span><Shield size={14} /> Anti-Cheat</span>
            <span><CreditCard size={14} /> Instant Withdrawal</span>
          </div>
        </motion.div>
      </header>

      {/* Stats */}
      <section className="stats-section">
        <div className="stats-grid">
          <motion.div className="stat-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0 }}>
            <div className="stat-value">{settings?.app_stats?.active_players || '50K+'}</div>
            <div className="stat-label">Active Players</div>
          </motion.div>
          <motion.div className="stat-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
            <div className="stat-value">{settings?.app_stats?.total_tournaments || '500+'}</div>
            <div className="stat-label">Tournaments</div>
          </motion.div>
          <motion.div className="stat-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
            <div className="stat-value">{settings?.app_stats?.prize_distributed || '₹10L+'}</div>
            <div className="stat-label">Prizes Won</div>
          </motion.div>
        </div>
      </section>

      {/* How it works */}
      <section className="how-it-works">
        <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}>How It Works</motion.h2>
        <p className="section-subtitle">Get started in 3 simple steps</p>
        <div className="steps-grid">
          <motion.div className="step-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
            <div className="step-number">1</div>
            <Smartphone size={32} className="step-icon" />
            <h3>Download the App</h3>
            <p>Free to install. Works on all Android devices.</p>
          </motion.div>
          <motion.div className="step-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
            <div className="step-number">2</div>
            <Trophy size={32} className="step-icon" />
            <h3>Join a Tournament</h3>
            <p>Pick your game, pay entry fee, and compete.</p>
          </motion.div>
          <motion.div className="step-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }}>
            <div className="step-number">3</div>
            <Zap size={32} className="step-icon" />
            <h3>Win & Withdraw</h3>
            <p>Get prize money in your UPI within hours.</p>
          </motion.div>
        </div>
        <a href={appUrl ?? '#'} className="btn-primary" style={{ marginTop: '2rem', ...(!hasAppUrl ? { opacity: 0.7, pointerEvents: 'none' } : {}) }}>
          <Download size={20} /> Start Winning Now
        </a>
      </section>

      {/* Features */}
      <section id="features" className="features">
        <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}>Why Players Trust Esport Adda</motion.h2>
        <p className="section-subtitle">Built for Indian gamers, by gamers</p>
        <div className="feature-grid">
          <FeatureCard icon={<Trophy />} title="Real Prize Tournaments" description="Daily cash tournaments in BGMI, Free Fire, and more. Entry fees from ₹10. Win real money." />
          <FeatureCard icon={<Zap />} title="Instant UPI Withdrawals" description="Withdraw your winnings directly to UPI. Processed within 2-4 hours. No hidden fees." />
          <FeatureCard icon={<Shield />} title="Fair Play Guarantee" description="Anti-cheat system and verified results. Every match is monitored for a level playing field." />
          <FeatureCard icon={<Users />} title="Active Community" description="Join thousands of serious gamers. 24/7 support via WhatsApp & Telegram." />
        </div>
      </section>

      {/* Games */}
      <section className="games-section">
        <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}>Play Your Favorite Games</motion.h2>
        <p className="section-subtitle">Tournaments for the games you love</p>
        <div className="games-grid">
          {['BGMI', 'Free Fire', 'COD Mobile', 'Valorant Mobile', 'More Coming'].map((game, i) => (
            <motion.div key={game} className="game-chip" initial={{ opacity: 0, scale: 0.9 }} whileInView={{ opacity: 1, scale: 1 }} transition={{ delay: i * 0.05 }}>
              {game}
            </motion.div>
          ))}
        </div>
      </section>

      {/* Testimonials */}
      <section className="testimonials-section">
        <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}>What Players Say</motion.h2>
        <div className="testimonials-grid">
          <motion.div className="testimonial-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }}>
            <div className="stars"><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /></div>
            <p>&quot;Withdrew ₹2,500 within 3 hours. Legit platform, no issues.&quot;</p>
            <span>— Rahul M., Delhi</span>
          </motion.div>
          <motion.div className="testimonial-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
            <div className="stars"><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /></div>
            <p>&quot;Best tournament app I&apos;ve used. Fair matches, quick payouts.&quot;</p>
            <span>— Priya S., Mumbai</span>
          </motion.div>
          <motion.div className="testimonial-card" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
            <div className="stars"><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /><Star size={16} fill="currentColor" /></div>
            <p>&quot;Support team is great. Resolved my query in minutes.&quot;</p>
            <span>— Arjun K., Bangalore</span>
          </motion.div>
        </div>
      </section>

      {/* FAQ */}
      <section className="faq-section">
        <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}>Frequently Asked Questions</motion.h2>
        <div className="faq-grid">
          <div className="faq-item">
            <h4>Is Esport Adda safe and legit?</h4>
            <p>Yes. We use secure payment gateways (Razorpay, UPI), have a fair play system, and process thousands of withdrawals every month. Your money is safe.</p>
          </div>
          <div className="faq-item">
            <h4>How fast are withdrawals?</h4>
            <p>UPI withdrawals are processed within 2-4 hours on business days. Most users receive their money the same day.</p>
          </div>
          <div className="faq-item">
            <h4>What games can I play?</h4>
            <p>We host tournaments for BGMI, Free Fire, COD Mobile, and more. New games are added regularly.</p>
          </div>
          <div className="faq-item">
            <h4>Is there a minimum deposit?</h4>
            <p>You can start with as little as ₹10. Add money via UPI or Razorpay and join tournaments that match your budget.</p>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="final-cta">
        <motion.div initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} className="cta-box">
          <h2>Ready to Win?</h2>
          <p>Join 50K+ players. Download now and get your first tournament started.</p>
          <a href={appUrl ?? '#'} className="btn-primary btn-download-lg" style={!hasAppUrl ? { opacity: 0.7, pointerEvents: 'none' } : undefined}>
            <Download size={24} /> Download Esport Adda
          </a>
          <div className="cta-trust">
            <CheckCircle2 size={18} /> 100% Free to Download &nbsp;•&nbsp; <CheckCircle2 size={18} /> No Hidden Fees
          </div>
        </motion.div>
      </section>
    </>
  );
};

const LegalPage: React.FC = () => {
  const { docId } = useParams<{ docId: string }>();
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
    let cancelled = false;
    const fetchDoc = async () => {
      if (!docId) return;
      setIsLoading(true);
      setError(null);
      const { data, error: err } = await supabase.from('legal_documents').select().eq('id', docId).single();
      if (cancelled) return;
      if (err) {
        setError(err.message || 'Failed to load document');
        setContent('');
        setTitle('');
      } else if (data) {
        setContent(data.content ?? '');
        setTitle(data.title ?? '');
      }
      setIsLoading(false);
    };
    fetchDoc();
    return () => { cancelled = true; };
  }, [docId, pathname]);

  return (
    <div className="legal-container">
      <Link to="/" className="back-link"><ArrowLeft size={16} /> Back to Home</Link>
      {isLoading && <p style={{ color: 'var(--text-muted)', textAlign: 'center' }}>Loading...</p>}
      {error && <p style={{ color: 'var(--error, #ef4444)', textAlign: 'center' }}>{error}</p>}
      {!isLoading && !error && (
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="legal-content">
          <h1 style={{ color: 'white', marginBottom: '2rem' }}>{title}</h1>
          <ReactMarkdown>{content}</ReactMarkdown>
        </motion.div>
      )}
    </div>
  );
};

const App: React.FC = () => {
  const [settings, setSettings] = useState<WebSettings | null>(null);

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    const { data } = await supabase.from('website_settings').select('key, value');
    if (data) {
      const mapped: any = {};
      data.forEach((item) => mapped[item.key] = item.value);
      setSettings(mapped as WebSettings);
    }
  };

  return (
    <HelmetProvider>
      <Router>
        <div className="app-container">
          <Navbar userAppUrl={settings?.apk_links?.user_app} />
          <Routes>
            <Route path="/" element={<Home settings={settings} />} />
            <Route path="/tournaments" element={<TournamentsPage />} />
            <Route path="/blog" element={<BlogPage />} />
            <Route path="/blog/:slug" element={<BlogPostPage />} />
            <Route path="/legal/:docId" element={<LegalPage />} />
          </Routes>
          <Footer settings={settings} />
        </div>
      </Router>
    </HelmetProvider>
  );
};

const FeatureCard: React.FC<{ icon: React.ReactNode; title: string; description: string }> = ({ icon, title, description }) => (
  <motion.div className="feature-card" whileHover={{ y: -5 }} initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }}>
    <div className="feature-icon">{icon}</div>
    <h3>{title}</h3>
    <p>{description}</p>
  </motion.div>
);

export default App;
