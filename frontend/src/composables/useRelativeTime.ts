/**
 * useRelativeTime - Composable for relative time formatting
 * FRD: 01_REQUIREMENTS/notifications.md v1.1
 */

/**
 * Formats an ISO date string into a relative time string
 * @param isoDate - ISO 8601 date string
 * @returns Relative time string (e.g., "Hace 5 min", "Ayer", "15 Ene")
 */
export const formatRelativeTime = (isoDate: string): string => {
  const date = new Date(isoDate);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  // Less than 1 minute
  if (diffMinutes < 1) {
    return 'Ahora';
  }

  // Less than 1 hour
  if (diffMinutes < 60) {
    return `Hace ${diffMinutes} min`;
  }

  // Less than 24 hours
  if (diffHours < 24) {
    return `Hace ${diffHours}h`;
  }

  // Yesterday
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  if (date.toDateString() === yesterday.toDateString()) {
    return 'Ayer';
  }

  // Less than 7 days
  if (diffDays < 7) {
    return `Hace ${diffDays} días`;
  }

  // Older - show date
  const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  const day = date.getDate();
  const month = months[date.getMonth()];

  // If same year, show day and month
  if (date.getFullYear() === now.getFullYear()) {
    return `${day} ${month}`;
  }

  // Different year, show full date
  return `${day} ${month} ${date.getFullYear()}`;
};

export const useRelativeTime = () => {
  return {
    formatRelativeTime,
  };
};
