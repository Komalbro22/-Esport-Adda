import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { supabase } from '../supabase';
import { ArrowLeft, FileText, Calendar } from 'lucide-react';
import { SeoHead } from '../components/SeoHead';

interface BlogPost {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  category: string | null;
  published_at: string;
  image_url: string | null;
}

export const BlogPage: React.FC = () => {
  const [posts, setPosts] = useState<BlogPost[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchPosts();
  }, []);

  const fetchPosts = async () => {
    const { data } = await supabase
      .from('blog_posts')
      .select('id, slug, title, excerpt, category, published_at, image_url')
      .eq('is_published', true)
      .order('published_at', { ascending: false })
      .limit(20);
    setPosts((data as BlogPost[]) ?? []);
    setIsLoading(false);
  };

  const formatDate = (iso: string) =>
    new Date(iso).toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    });

  return (
    <div className="page-container">
      <SeoHead
        title="Blog & Tips | Esport Adda"
        description="Tips, updates, and guides for esport tournaments. Learn how to join, win, and dominate on Esport Adda."
        url="https://esportadda.in/blog"
      />
      <Link to="/" className="back-link" style={{ marginBottom: '2rem' }}>
        <ArrowLeft size={16} /> Back to Home
      </Link>
      <motion.h1
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ marginBottom: '0.5rem', fontSize: '2rem' }}
      >
        Blog & News
      </motion.h1>
      <p style={{ color: 'var(--text-muted)', marginBottom: '2rem' }}>
        Tips, updates, and featured content for gamers.
      </p>

      {isLoading ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-muted)' }}>
          Loading posts...
        </div>
      ) : posts.length === 0 ? (
        <div className="blog-card" style={{ textAlign: 'center', padding: '4rem' }}>
          <FileText size={48} style={{ color: 'var(--text-muted)', marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-muted)' }}>No posts yet. Check back soon!</p>
        </div>
      ) : (
        <div className="blog-grid">
          {posts.map((p, i) => (
            <motion.div
              key={p.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
            >
              <Link to={`/blog/${p.slug}`} className="blog-card" style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}>
                {p.image_url && (
                  <img src={p.image_url} alt="" style={{ width: '100%', height: 180, objectFit: 'cover', borderRadius: 12, marginBottom: '1rem' }} />
                )}
                <span style={{ color: 'var(--primary)', fontSize: '0.75rem', fontWeight: 600, textTransform: 'uppercase' }}>
                  {p.category || 'News'}
                </span>
                <h3 style={{ fontSize: '1.25rem', margin: '0.5rem 0' }}>{p.title}</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', lineHeight: 1.6 }}>
                  {p.excerpt || p.title}
                </p>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--text-muted)', fontSize: '0.8rem', marginTop: '1rem' }}>
                  <Calendar size={14} /> {formatDate(p.published_at)}
                </span>
              </Link>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
};
