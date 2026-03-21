import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { supabase } from '../supabase';
import { Trophy, Calendar, Users, IndianRupee, ArrowLeft, Gamepad2 } from 'lucide-react';
import { SeoHead } from '../components/SeoHead';

interface Tournament {
  id: string;
  title: string;
  entry_fee: number;
  total_slots: number;
  joined_slots: number;
  status: string;
  start_time: string | null;
  tournament_type: string;
  games: { name: string; logo_url?: string } | { name: string; logo_url?: string }[] | null;
}

const statusColors: Record<string, string> = {
  upcoming: '#22c55e',
  ongoing: '#eab308',
  completed: '#94a3b8',
  cancelled: '#ef4444'
};

export const TournamentsPage: React.FC = () => {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [filter, setFilter] = useState<'upcoming' | 'ongoing' | 'all'>('upcoming');

  useEffect(() => {
    fetchTournaments();
  }, [filter]);

  const fetchTournaments = async () => {
    setIsLoading(true);
    let query = supabase
      .from('tournaments')
      .select('id, title, entry_fee, total_slots, joined_slots, status, start_time, tournament_type, games(name, logo_url)')
      .order('start_time', { ascending: true, nullsFirst: false });

    if (filter !== 'all') {
      query = query.eq('status', filter);
    }

    const { data } = await query.limit(50);
    setTournaments(((data ?? []) as unknown) as Tournament[]);
    setIsLoading(false);
  };

  const formatDate = (iso: string | null) => {
    if (!iso) return 'TBD';
    const d = new Date(iso);
    return d.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatType = (t: string) => t?.charAt(0).toUpperCase() + t?.slice(1) || 'Solo';

  return (
    <div className="page-container">
      <SeoHead
        title="Tournaments | Esport Adda"
        description="Browse upcoming and ongoing esport tournaments. Join daily competitions, win real prizes in BGMI, Free Fire, and more."
        url="https://esportadda.in/tournaments"
      />
      <Link to="/" className="back-link" style={{ marginBottom: '2rem' }}>
        <ArrowLeft size={16} /> Back to Home
      </Link>
      <motion.h1
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ marginBottom: '1rem', fontSize: '2rem' }}
      >
        Tournaments
      </motion.h1>
      <p style={{ color: 'var(--text-muted)', marginBottom: '2rem' }}>
        Browse and join tournaments. Download the app to participate.
      </p>

      <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
        {(['upcoming', 'ongoing', 'all'] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className="btn-secondary"
            style={{
              background: filter === f ? 'var(--primary)' : 'var(--glass)',
              borderColor: filter === f ? 'var(--primary)' : 'var(--glass-border)',
              padding: '0.5rem 1rem',
              fontSize: '0.875rem'
            }}
          >
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-muted)' }}>
          Loading tournaments...
        </div>
      ) : tournaments.length === 0 ? (
        <div className="tournament-card" style={{ textAlign: 'center', padding: '4rem' }}>
          <Gamepad2 size={48} style={{ color: 'var(--text-muted)', marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-muted)' }}>No tournaments found. Check back soon!</p>
        </div>
      ) : (
        <div className="tournament-grid">
          {tournaments.map((t, i) => (
            <motion.div
              key={t.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              className="tournament-card"
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  {(() => {
                    const g = Array.isArray(t.games) ? t.games[0] : t.games;
                    return g?.logo_url ? (
                      <img src={g.logo_url} alt="" style={{ width: 40, height: 40, borderRadius: 10, objectFit: 'cover' }} />
                    ) : (
                      <div style={{ width: 40, height: 40, borderRadius: 10, background: 'var(--glass)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Trophy size={20} color="var(--primary)" />
                      </div>
                    );
                  })()}
                  <span style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                    {(Array.isArray(t.games) ? t.games[0] : t.games)?.name || 'Game'}
                  </span>
                </div>
                <span
                  style={{
                    padding: '0.25rem 0.5rem',
                    borderRadius: 6,
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    background: `${statusColors[t.status] || '#64748b'}20`,
                    color: statusColors[t.status] || '#94a3b8'
                  }}
                >
                  {t.status?.toUpperCase()}
                </span>
              </div>
              <h3 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>{t.title}</h3>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                  <IndianRupee size={14} /> {t.entry_fee}
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                  <Users size={14} /> {t.joined_slots}/{t.total_slots}
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                  <Calendar size={14} /> {formatDate(t.start_time)}
                </span>
                <span>{formatType(t.tournament_type)}</span>
              </div>
              <a
                href="/"
                className="btn-primary"
                style={{ marginTop: '1rem', display: 'inline-flex', textDecoration: 'none' }}
              >
                Download App to Join
              </a>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
};
