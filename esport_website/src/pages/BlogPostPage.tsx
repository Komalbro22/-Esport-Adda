import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import { supabase } from '../supabase';
import { ArrowLeft, Calendar, User } from 'lucide-react';
import { SeoHead } from '../components/SeoHead';

interface BlogPost {
  title: string;
  excerpt: string | null;
  content: string;
  author: string | null;
  published_at: string;
  image_url: string | null;
  category: string | null;
}

export const BlogPostPage: React.FC = () => {
  const { slug } = useParams<{ slug: string }>();
  const [post, setPost] = useState<BlogPost | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (slug) fetchPost();
  }, [slug]);

  const fetchPost = async () => {
    if (!slug) return;
    setIsLoading(true);
    setError(null);
    const { data, error: fetchError } = await supabase
      .from('blog_posts')
      .select('title, excerpt, content, author, published_at, image_url, category')
      .eq('slug', slug)
      .eq('is_published', true)
      .single();
    if (fetchError) {
      setError(fetchError.message);
      setPost(null);
    } else {
      setPost(data as BlogPost);
    }
    setIsLoading(false);
  };

  const formatDate = (iso: string) =>
    new Date(iso).toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    });

  if (isLoading) {
    return (
      <div className="page-container">
        <p style={{ color: 'var(--text-muted)', textAlign: 'center' }}>Loading...</p>
      </div>
    );
  }

  if (error || !post) {
    return (
      <div className="page-container">
        <Link to="/blog" className="back-link"><ArrowLeft size={16} /> Back to Blog</Link>
        <p style={{ color: 'var(--error, #ef4444)', textAlign: 'center' }}>{error || 'Post not found'}</p>
      </div>
    );
  }

  const url = `https://esportadda.in/blog/${slug}`;

  return (
    <div className="page-container">
      <SeoHead
        title={`${post.title} | Esport Adda Blog`}
        description={post.excerpt || post.title}
        url={url}
        type="article"
        publishedTime={post.published_at}
      />
      <Link to="/blog" className="back-link" style={{ marginBottom: '2rem' }}>
        <ArrowLeft size={16} /> Back to Blog
      </Link>
      <motion.article
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className="legal-content"
        style={{ maxWidth: 800, margin: '0 auto' }}
      >
        {post.image_url && (
          <img src={post.image_url} alt="" style={{ width: '100%', maxHeight: 400, objectFit: 'cover', borderRadius: 16, marginBottom: '2rem' }} />
        )}
        <span style={{ color: 'var(--primary)', fontSize: '0.75rem', fontWeight: 600, textTransform: 'uppercase' }}>
          {post.category || 'News'}
        </span>
        <h1 style={{ color: 'white', marginBottom: '1rem', marginTop: '0.5rem' }}>{post.title}</h1>
        <div style={{ display: 'flex', gap: '1.5rem', color: 'var(--text-muted)', fontSize: '0.875rem', marginBottom: '2rem' }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <User size={14} /> {post.author || 'Esport Adda'}
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Calendar size={14} /> {formatDate(post.published_at)}
          </span>
        </div>
        <div className="legal-content" style={{ padding: 0, background: 'transparent', border: 'none' }}>
          <ReactMarkdown>{post.content}</ReactMarkdown>
        </div>
      </motion.article>
    </div>
  );
};
