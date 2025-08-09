# Mojo🔥 GPU Programming Workshop

A comprehensive workshop introducing GPU programming with Mojo🔥, featuring hands-on exercises, interactive slides, and real-world applications.

## 🎯 Workshop Overview

This workshop covers:
- **Part 1: Foundations** - Why Mojo, setup, and language fundamentals
- **Part 2: Practical Implementation** - Hands-on GPU programming with Mojo GPU Puzzles

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

- **Mojo Documentation**: [docs.modular.com/mojo](https://docs.modular.com/mojo)
- **GPU Programming Guide**: [docs.modular.com/mojo/manual/gpu](https://docs.modular.com/mojo/manual/gpu)
- **GPU Puzzles**: [github.com/modular/mojo-gpu-puzzles](https://github.com/modular/mojo-gpu-puzzles)
- **PyTorch Custom Ops**: [docs.modular.com/max/tutorials/custom-kernels-pytorch](https://docs.modular.com/max/tutorials/custom-kernels-pytorch)
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

**Happy GPU Programming with Mojo! 🔥**
