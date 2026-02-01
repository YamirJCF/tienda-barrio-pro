/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{vue,js,ts,jsx,tsx}",
    ],
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                // Primary colors (from designs)
                'primary': '#245feb',
                'primary-dark': '#1a46b0',
                'primary-light': '#5a8aff',

                // Accent colors
                'accent-green': '#0df2aa',
                'accent-emerald': '#10b981',

                // Background colors
                'background-light': '#f6f6f8',
                'background-dark': '#111621',

                // Surface colors
                'surface-light': '#ffffff',
                'surface-dark': '#1e2736',
            },
            fontFamily: {
                'display': ['Work Sans', 'sans-serif'],
                'body': ['Work Sans', 'sans-serif'],
            },
            borderRadius: {
                'DEFAULT': '0.5rem',
                'lg': '0.75rem',
                'xl': '1rem',
                '2xl': '1.5rem',
                'full': '9999px',
            },
        },
    },
    plugins: [],
}
