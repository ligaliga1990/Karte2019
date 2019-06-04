import peasy.org.apache.commons.math.*;
import peasy.*;
import peasy.org.apache.commons.math.geometry.*;


PeasyCam camera;
Table table;

String [][] test = new String[29][8];
PImage latvia_map_img;


int rows = 0;
int columns = 0;

int default_radius = 4;
float space = default_radius * 2;
float offset = default_radius * 2;
int sphere_detail_nr = 30;

float app_width = 0;
float app_height = 0;


ArrayList<Dot> dots = new ArrayList<Dot>();


boolean mouse_actions = true;

void setup() {
  fullScreen(P3D);

  // Define screen dimensions with offset
  app_width = displayWidth - offset;
  app_height = displayHeight - offset;

  println("Screen Size width: " + app_width);
  println("Screen Size height: " + app_height);

  latvia_map_img = loadImage("latvia_map.png");
  latvia_map_img.resize(displayWidth, displayHeight);

  println("Image width: " + latvia_map_img.width);
  println("Image height: " + latvia_map_img.height);

  table = loadTable("populacija.csv","header"); // sketch mapē ir dati saglabāti csv failā, kas ar notepad ir pārveidots, lai visu atdala komati
  println(table.getRowCount() + " total rows in table");
  println(table.getColumnCount() + " total rows in table");

  // Add 3D world camera
  camera = new PeasyCam(this, displayWidth / 2, displayHeight / 2, 0, 1000);
  camera.setMinimumDistance(400);
  camera.setMaximumDistance(displayWidth * 3);

  calculate_rows();
  calculate_columns();

  get_dots();

}

void get_dots() {
  for(int row = 0; row <= rows; row = row + 1)  { // // skaitlis = horizontālais daudzums
    for (int col = 0; col <= columns; col = col + 1) { // skaitlis ir vertikālais daudzums
      int x = parseInt(offset + (default_radius * 2 + space) * col); // horizontālais atstatums
      int y = parseInt(offset + (default_radius * 2 + space) * row); // vertikālais` atstatums
      int z = 0;

      if(latvia_map_img.width < x || latvia_map_img.height - 30 < y) continue;

      int alpha = get_coord_alpha_value(latvia_map_img, x, y);
      if (alpha < 100) {
        dots.add(new Dot(alpha, x, y, z, default_radius));
      }
    }
  }
}


void draw() {
  background(#000000);
  draw_dots();
}





int calculate_rows() {
  rows =  parseInt((app_height) / (default_radius * 2 + space));
  return rows;
}

int calculate_columns() {
  columns =  parseInt((app_width) / (default_radius * 2 + space));
  return columns;
}


int get_coord_alpha_value(PImage img, int x, int y) {
  PImage tmpImage = img.get(x, y, 1, 1);
  int t_alpha_value = (int) alpha(tmpImage.pixels[0]);
  return t_alpha_value;
}

void draw_dots() {
  // The second is using an enhanced loop:
  for (Dot dot : dots) {
    dot.draw();
  }
}

void spherePosition(float x, float y, float z, float sizeSphere) {
  // draws a sphere at x,y,z with size sizeSphere
  pushMatrix();
  noStroke();
  fill(#ffffff);
  translate(x, y, z);
  sphereDetail(sphere_detail_nr);
  sphere(sizeSphere);
  popMatrix();
}

class Dot {
  public int alpha;
  public int x, y, z;
  public int radius;

  Dot(int a, int x, int y, int z, int r) {
    this.alpha = a;
    this.x = x;
    this.y = y;
    this.z = z;
    this.radius = r;
  }

  public void draw() {
    spherePosition(this.x, this.y, this.z, this.radius);
  }
}
