export const paths = {
  home: '/main',
  main: [
    {
      key: 'chat',
      title: 'Chat',
      href: '/',
      icon: 'chat',
      matcher: { type: 'equals', href: '/' }, // Type equals/startsWith/include/
    },
    {
      key: 'documents',
      title: 'Documents',
      href: 'documents',
      icon: 'article',
      matcher: { type: 'equals', href: '/documents' }, // Type equals/startsWith/include/
    },
  ],
  errors: { notFound: '/errors/not-found' },
} as const;
