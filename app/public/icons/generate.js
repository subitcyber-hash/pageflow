// Run: node generate.js
// Generates PNG icons from SVG using canvas
// Install: npm install canvas
const { createCanvas } = require("canvas");
const fs = require("fs");
const path = require("path");

const sizes = [72, 96, 128, 144, 152, 192, 384, 512];

function generateIcon(size) {
  const canvas = createCanvas(size, size);
  const ctx    = canvas.getContext("2d");

  // Background
  const grad = ctx.createLinearGradient(0, 0, size, size);
  grad.addColorStop(0, "#4f46e5");
  grad.addColorStop(1, "#7c3aed");
  ctx.fillStyle = grad;

  // Rounded rect
  const r = size * 0.22;
  ctx.beginPath();
  ctx.moveTo(r, 0);
  ctx.lineTo(size - r, 0);
  ctx.quadraticCurveTo(size, 0, size, r);
  ctx.lineTo(size, size - r);
  ctx.quadraticCurveTo(size, size, size - r, size);
  ctx.lineTo(r, size);
  ctx.quadraticCurveTo(0, size, 0, size - r);
  ctx.lineTo(0, r);
  ctx.quadraticCurveTo(0, 0, r, 0);
  ctx.closePath();
  ctx.fill();

  // Letter P
  ctx.fillStyle = "white";
  ctx.font      = `bold ${size * 0.5}px Arial`;
  ctx.textAlign    = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("P", size / 2, size / 2);

  const buffer = canvas.toBuffer("image/png");
  fs.writeFileSync(path.join(__dirname, `icon-${size}.png`), buffer);
  console.log(`Generated icon-${size}.png`);
}

sizes.forEach(generateIcon);
console.log("All icons generated!");
