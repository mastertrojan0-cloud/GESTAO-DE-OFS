interface FlagProps {
  country: 'VE' | 'BR';
  className?: string;
  title?: string;
}

export function Flag({ country, className = 'h-4 w-6', title }: FlagProps) {
  if (country === 'VE') {
    return (
      <svg
        viewBox="0 0 24 16"
        className={className}
        role="img"
        aria-label={title || 'Venezuela'}
      >
        <title>{title || 'Venezuela'}</title>
        <rect width="24" height="16" fill="#CF142B" />
        <rect width="24" height="10.67" fill="#00247D" />
        <rect width="24" height="5.33" fill="#FCD116" />
      </svg>
    );
  }
  return (
    <svg
      viewBox="0 0 28 20"
      className={className}
      role="img"
      aria-label={title || 'Brasil'}
    >
      <title>{title || 'Brasil'}</title>
      <rect width="28" height="20" fill="#009C3B" />
      <polygon points="14,2 26,10 14,18 2,10" fill="#FFDF00" />
      <circle cx="14" cy="10" r="4" fill="#002776" />
    </svg>
  );
}
