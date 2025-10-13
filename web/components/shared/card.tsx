'use client';

import type { PropsWithChildren } from 'react';

type CardProps = PropsWithChildren<{
  title?: string;
  className?: string;
}>;

export function Card({ title, className = '', children }: CardProps) {
  return (
    <section className={`space-y-2 rounded-lg border border-gray-200 p-4 shadow-sm ${className}`.trim()}>
      {title ? <h3 className="text-lg font-semibold">{title}</h3> : null}
      <div className="text-sm text-gray-700">{children}</div>
    </section>
  );
}

