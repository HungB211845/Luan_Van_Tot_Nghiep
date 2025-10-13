'use client';

import type { ButtonHTMLAttributes, PropsWithChildren } from 'react';

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary';
};

export function Button({ children, variant = 'primary', className = '', ...props }: PropsWithChildren<ButtonProps>) {
  const base =
    'inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-medium transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2';
  const styles =
    variant === 'primary'
      ? 'bg-green-600 text-white hover:bg-green-700 focus-visible:outline-green-600'
      : 'border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 focus-visible:outline-gray-300';

  return (
    <button className={`${base} ${styles} ${className}`.trim()} {...props}>
      {children}
    </button>
  );
}

