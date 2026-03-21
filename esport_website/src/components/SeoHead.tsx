import { Helmet } from 'react-helmet-async';

interface SeoHeadProps {
  title?: string;
  description?: string;
  image?: string;
  url?: string;
  type?: 'website' | 'article';
  publishedTime?: string;
  modifiedTime?: string;
}

const SITE_URL = 'https://esportadda.in';

export const SeoHead: React.FC<SeoHeadProps> = ({
  title = 'Esport Adda | The Ultimate Esport Competition Platform',
  description = 'Download Esport Adda to join professional tournaments, win real prizes, and dominate the leaderboard in your favorite mobile games.',
  image = `${SITE_URL}/og-image.jpg`,
  url = SITE_URL,
  type = 'website',
  publishedTime,
  modifiedTime
}) => (
  <Helmet>
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={url} />

    {/* Open Graph */}
    <meta property="og:type" content={type} />
    <meta property="og:url" content={url} />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content={image} />
    <meta property="og:site_name" content="Esport Adda" />
    <meta property="og:locale" content="en_IN" />
    {publishedTime && <meta property="article:published_time" content={publishedTime} />}
    {modifiedTime && <meta property="article:modified_time" content={modifiedTime} />}

    {/* Twitter */}
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:url" content={url} />
    <meta name="twitter:title" content={title} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content={image} />
  </Helmet>
);
