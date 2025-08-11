# Regex Engine in Mojo🔥

A presentation about the mojo-regex library, showcasing its hybrid DFA/NFA architecture, SIMD optimizations, and performance achievements.

## 🎯 Presentation Overview

This presentation covers:
- **Part 1: Introduction & Motivation** - What is mojo-regex and why build it in Mojo
- **Part 2: Architecture Deep Dive** - Hybrid DFA/NFA design and components
- **Part 3: Performance Optimizations** - SIMD, memory, and compile-time optimizations
- **Part 4: Practical Examples** - Usage, benchmarks, and future roadmap

## 🛠️ Installation

### 1. Install Pixi

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

### 2. Clone and Setup

```bash
git clone https://github.com/modular/workshops
cd mojo-gpu-programming
```

### 3. Install Dependencies

```bash
pixi run install
```

This will automatically install:
- Node.js (>=22.13.0)
- All npm dependencies for the presentation
- Reveal.js presentation framework

## 🚀 Usage

### Development Mode (Auto-reload)

```bash
pixi run dev-slides
```
Opens slides at `http://localhost:3034` with live reload when you edit `slides.md`.

### Presentation Mode

```bash
pixi run slides
```
Serves slides at `http://localhost:3033` for stable presentation.

### PDF Export

```bash
pixi run pdf
```
Starts server and provides instructions for manual PDF export via Chrome.

**Automated PDF Export:**
```bash
npm run export-pdf
```
Generates `mojo-gpu-workshop.pdf` automatically with emoji support.

## 🔧 Troubleshooting

### Common Issues

**Slides not loading:**
```bash
# Check if port is available
lsof -i :3033
# Try different port
pixi run npx serve . -p 4000
```

**Syntax highlighting errors:**
- Ensure `highlight.js` and `mojolang.js` are properly loaded
- Check browser console for JavaScript errors

## 📖 Additional Resources

- **Mojo-Regex Repository**: [github.com/msaelices/mojo-regex](https://github.com/msaelices/mojo-regex)
- **Performance Tips**: [Performance Optimization Guide](https://github.com/msaelices/mojo-regex/blob/main/docs/performance-tips.md)
- **Contributing Guide**: [CONTRIBUTING.md](https://github.com/msaelices/mojo-regex/blob/main/CONTRIBUTING.md)
- **Mojo Documentation**: [docs.modular.com/mojo](https://docs.modular.com/mojo)
- **Community Forum**: [forum.modular.com](https://forum.modular.com)

## 🤝 Contributing

Found an issue or want to improve the workshop content?
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📧 Contact

For questions about this workshop:
- **Community**: [forum.modular.com](https://forum.modular.com)
- **Documentation**: [docs.modular.com](https://docs.modular.com)

---

**Happy Regex Matching with Mojo! 🔥**
