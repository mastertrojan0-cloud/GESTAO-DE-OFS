import { useState, useEffect, useRef } from 'react';

export function useDebounce<T>(value: T, delay: number = 300): T {
  const [debounced, setDebounced] = useState<T>(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}

export function usePagination(total: number, defaultLimit: number = 20) {
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(defaultLimit);
  const totalPages = Math.ceil(total / limit);

  return {
    page,
    limit,
    totalPages,
    setPage,
    setLimit,
    offset: (page - 1) * limit,
    hasNext: page < totalPages,
    hasPrev: page > 1,
  };
}
