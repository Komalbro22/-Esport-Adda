import React, { useEffect, useState } from 'react';
import { supabase } from './supabase';
import { Download, Zap, Trophy, Shield, Users, Instagram, Send, Mail, ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { BrowserRouter as Router, Routes, Route, Link, useParams, useLocation } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
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
    <div className="cta-group">
      <a href={userAppUrl} className="btn-primary" style={{ padding: '0.6rem 1.2rem', fontSize: '0.9rem' }}>
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
          Building the future of mobile esports in India. Join the revolution today.
        </p>
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
        <a href={settings?.contact_info?.instagram} className="footer-link"><Instagram size={20} /></a>
        <a href={`https://wa.me/${settings?.contact_info?.whatsapp}`} className="footer-link"><Send size={20} /></a>
        <a href={`mailto:${settings?.contact_info?.email}`} className="footer-link"><Mail size={20} /></a>
      </div>
    </div>

    <div style={{ textAlign: 'center', marginTop: '3rem', color: 'var(--text-muted)', fontSize: '0.8rem' }}>
      © 2026 Esport Adda. All rights reserved.
    </div>
  </footer>
);

const Home: React.FC<{ settings: WebSettings | null }> = ({ settings }) => {
  const fadeInUp = {
    initial: { opacity: 0, y: 20 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.6 }
  };

  return (
    <>
      <header className="hero">
        <motion.div {...fadeInUp}>
          <div className="badge">New Season Live • Play & Win</div>
          <h1>The Ultimate Platform to <span>Dominate</span> Esport</h1>
          <p>Join thousands of players, participate in daily tournaments, and turn your gaming skills into real rewards. Fast, secure, and competitive.</p>

          <div className="cta-group">
            <a href={settings?.apk_links?.user_app} className="btn-primary">
              <Download size={20} /> Download for Android
            </a>
            <a href="#features" className="btn-secondary">Learn More</a>
          </div>
        </motion.div>
      </header>

      <section className="stats-grid">
        <motion.div className="stat-card" initial={{ opacity: 0, scale: 0.9 }} whileInView={{ opacity: 1, scale: 1 }}>
          <div className="stat-value">{settings?.app_stats?.active_players || '50K+'}</div>
          <div className="stat-label">Active Players</div>
        </motion.div>
        <motion.div className="stat-card" initial={{ opacity: 0, scale: 0.9 }} whileInView={{ opacity: 1, scale: 1 }} transition={{ delay: 0.1 }}>
          <div className="stat-value">{settings?.app_stats?.total_tournaments || '500+'}</div>
          <div className="stat-label">Tournaments</div>
        </motion.div>
        <motion.div className="stat-card" initial={{ opacity: 0, scale: 0.9 }} whileInView={{ opacity: 1, scale: 1 }} transition={{ delay: 0.2 }}>
          <div className="stat-value">{settings?.app_stats?.prize_distributed || '₹10L+'}</div>
          <div className="stat-label">Prizes Distributed</div>
        </motion.div>
      </section>

      <section id="features" className="features">
        <motion.h2 style={{ textAlign: 'center', marginBottom: '3rem', fontSize: '2.5rem' }} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}>
          Why Choose Esport Adda?
        </motion.h2>
        <div className="feature-grid">
          <FeatureCard icon={<Trophy />} title="Professional Tournaments" description="Compete in high-stakes tournaments with professional rules and fair matchmaking." />
          <FeatureCard icon={<Zap />} title="Instant Withdrawals" description="Win and withdraw your earnings instantly to your UPI or Bank account with zero delay." />
          <FeatureCard icon={<Shield />} title="Anti-Cheat System" description="Our advanced fair play system ensures a hacker-free environment for all players." />
          <FeatureCard icon={<Users />} title="Growing Community" description="Connect with fellow gamers, join clans, and rise through the leaderboards together." />
        </div>
      </section>
    </>
  );
};

const LegalPage: React.FC = () => {
  const { docId } = useParams<{ docId: string }>();
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
    fetchDoc();
  }, [docId, pathname]);

  const fetchDoc = async () => {
    if (!docId) return;
    const { data } = await supabase.from('legal_documents').select().eq('id', docId).single();
    if (data) {
      setContent(data.content);
      setTitle(data.title);
    }
  };

  return (
    <div className="legal-container">
      <Link to="/" className="back-link"><ArrowLeft size={16} /> Back to Home</Link>
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="legal-content">
        <h1 style={{ color: 'white', marginBottom: '2rem' }}>{title}</h1>
        <ReactMarkdown>{content}</ReactMarkdown>
      </motion.div>
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
    <Router>
      <div className="app-container">
        <Navbar userAppUrl={settings?.apk_links?.user_app} />
        <Routes>
          <Route path="/" element={<Home settings={settings} />} />
          <Route path="/legal/:docId" element={<LegalPage />} />
        </Routes>
        <Footer settings={settings} />
      </div>
    </Router>
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
