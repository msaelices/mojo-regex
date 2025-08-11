# Local Fonts Setup

This directory contains the local font files for the reveal.js presentation.

## Font Files Structure

Place your font files in this directory with the following naming convention:

### Inter Font Files

- `Inter-Light.woff2` and `Inter-Light.woff` (weight: 300)
- `Inter-Regular.woff2` and `Inter-Regular.woff` (weight: 400)
- `Inter-Medium.woff2` and `Inter-Medium.woff` (weight: 500)
- `Inter-SemiBold.woff2` and `Inter-SemiBold.woff` (weight: 600)
- `Inter-Bold.woff2` and `Inter-Bold.woff` (weight: 700)

### JetBrains Mono Font Files

- `JetBrainsMono-Regular.woff2` and `JetBrainsMono-Regular.woff` (weight: 400)
- `JetBrainsMono-Medium.woff2` and `JetBrainsMono-Medium.woff` (weight: 500)
- `JetBrainsMono-SemiBold.woff2` and `JetBrainsMono-SemiBold.woff` (weight: 600)

## Where to Download Fonts

### Inter Font Family

- Download from: <https://fonts.google.com/specimen/Inter>
- Or from: <https://github.com/rsms/inter/releases>

### JetBrains Mono

- Download from: <https://fonts.google.com/specimen/JetBrains+Mono>
- Or from: <https://github.com/JetBrains/JetBrainsMono/releases>

## Custom Fonts

To add your own custom fonts:

1. Add your font files (`.woff2` and `.woff` formats recommended) to this directory
2. Update the `fonts.css` file with new `@font-face` declarations
3. Update the CSS in `index.html` to use your custom font family

Example:

```css
@font-face {
    font-family: 'YourCustomFont';
    font-style: normal;
    font-weight: 400;
    font-display: swap;
    src: url('./YourCustomFont-Regular.woff2') format('woff2'),
         url('./YourCustomFont-Regular.woff') format('woff');
}
```

## Font Loading

The fonts are loaded via the `fonts.css` file which is linked in the `index.html`:

```html
<!-- Local Fonts -->
<link rel="stylesheet" href="fonts/fonts.css">
```

This replaces the Google Fonts import and provides:

- Faster loading (no external requests)
- Offline support
- Better privacy (no Google tracking)
- Consistent rendering across environments

## Fallback Fonts

The CSS includes fallback fonts in case your custom fonts don't load:

```css
font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
```
