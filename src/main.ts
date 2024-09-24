import {vec3, vec4} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';
import {gl} from './globals'; 
import Drawable from './rendering/gl/Drawable';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  geometry: "icosphere",
  tesselations: 8,
  color: [255, 0, 0],//default red color
  color2: [255, 255, 0],
  background: [0, 255, 255],
  scale: 5,
  'Reset': reset,
  'Load Scene': loadScene, // A function pointer, essentially
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let prevTesselations: number = 5;

function reset() {
  controls.tesselations = 5;
  controls.color = [255, 0, 0];
  controls.color2 = [255, 255, 0];
  controls.background = [0, 255, 255];
  controls.scale = 5;
}

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, "geometry", ["icosphere", "square", "cube"]);
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'scale', 0, 10);
  gui.add(controls, 'Reset');
  gui.add(controls, 'Load Scene');
  gui.addColor(controls, 'color');//colorpicker to gui
  gui.addColor(controls, 'color2');
  gui.addColor(controls, 'background');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(controls.background[0] / 255, controls.background[1] / 255, controls.background[2] / 255, 1.0);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/fireball-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/fireball-frag.glsl')),//'./shaders/lambert-frag.glsl'
  ]);

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.geometry === "icosphere" && controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    renderer.setClearColor(controls.background[0] / 255, controls.background[1] / 255, controls.background[2] / 255, 1.0);
    const colorVec = vec4.fromValues(controls.color[0] / 255, controls.color[1] / 255, controls.color[2] / 255, 1.0);
    const colorVec2 = vec4.fromValues(controls.color2[0] / 255, controls.color2[1] / 255, controls.color2[2] / 255, 1.0);
    let currentTime = performance.now() / 1000.0;  // Get time in seconds
    lambert.setTime(currentTime);
    lambert.setCameraPosition(camera.controls.eye);
    
    let geometry: Drawable = cube;
    if (controls.geometry === "icosphere") geometry = icosphere;
    if (controls.geometry === "square") geometry = square;

    renderer.render(camera, lambert, [
      geometry
    ], colorVec, colorVec2, controls.scale);
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
