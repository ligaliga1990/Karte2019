import peasy.org.apache.commons.math.*;
import peasy.*;
import peasy.org.apache.commons.math.geometry.*;

import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;


PeasyCam camera;
Table table;
PImage latvia_map_img;

// define images
String Latvia_img = "images/latvia_map.png";

// define animations
interface Z_ANIMS {
  int
  NONE         = 0,
  JUMP         = 1, 
  SPHERE_IT    = 2;
}

int z_animation = Z_ANIMS.NONE;
int z_random_distance = 10;




// app settings
float app_width;
float app_height;
int rows;
int columns;
Scene active_scene;

// sphere data and offsets
int default_radius = 4;
float space = default_radius * 2;
float offset = default_radius * 2;
int sphere_detail_nr = 20;


int next_scene_interval = 60 * 1000; // 60 sec
int max_total_people;
int people_per_dot;


ArrayList<Dot> dots = new ArrayList<Dot>();
ArrayList<Scene> scenes = new ArrayList<Scene>();


Easing[] easings = { 
  Ani.LINEAR, Ani.QUAD_IN, Ani.QUAD_OUT, Ani.QUAD_IN_OUT, Ani.CUBIC_IN, Ani.CUBIC_IN_OUT, Ani.CUBIC_OUT, Ani.QUART_IN, Ani.QUART_OUT, Ani.QUART_IN_OUT, Ani.QUINT_IN, Ani.QUINT_OUT, Ani.QUINT_IN_OUT, Ani.SINE_IN, Ani.SINE_OUT, Ani.SINE_IN_OUT, Ani.CIRC_IN, Ani.CIRC_OUT, Ani.CIRC_IN_OUT, Ani.EXPO_IN, Ani.EXPO_OUT, Ani.EXPO_IN_OUT, Ani.BACK_IN, Ani.BACK_OUT, Ani.BACK_IN_OUT, Ani.BOUNCE_IN, Ani.BOUNCE_OUT, Ani.BOUNCE_IN_OUT, Ani.ELASTIC_IN, Ani.ELASTIC_OUT, Ani.ELASTIC_IN_OUT
};

int anim_index = 26;
Easing currentEasing = easings[anim_index];


void setup() {
  fullScreen(P3D);

  // Ani.init() must be called always first!
  Ani.init(this);

  // Define screen dimensions with offset
  app_width = displayWidth - offset;
  app_height = displayHeight - offset;

  println("Screen Size width: " + app_width);
  println("Screen Size height: " + app_height);

  latvia_map_img = loadImage(Latvia_img);
  latvia_map_img.resize(displayWidth, displayHeight);
  
  

  println("Image width: " + latvia_map_img.width);
  println("Image height: " + latvia_map_img.height);

  // Add 3D world camera
  camera = new PeasyCam(this, displayWidth / 2, displayHeight / 2, 0, 1000);
  camera.setMinimumDistance(400);
  camera.setMaximumDistance(displayWidth * 3);

  calculate_rows();
  calculate_columns();

  load_data();
  get_dots();

  if (dots.size() > 0) people_per_dot = max_total_people / dots.size();

  println("dots: " + dots.size());
  println("max total people: " + max_total_people);
  println("peopel per dot: " + people_per_dot);

  int divider = 2;
  people_per_dot = people_per_dot / divider;

  println("peopel per dot diveded by " + divider + ": " + people_per_dot);
  set_active_scene(0);
}

void load_data() {
  println("==> Load data:");
  table = loadTable("data/data.csv","header"); // sketch mapē ir dati saglabāti csv failā, kas ar notepad ir pārveidots, lai visu atdala komati

  int columns = table.getColumnCount();
  int rows = table.getRowCount();

  println(rows + " total rows in table");
  println(columns + " total rows in table");

  for (TableRow row : table.rows()) {
    String name = row.getString("NAME");
    String parent = row.getString("PARENT");
    int year = row.getInt("YEAR");

    if (parent.length() == 0) {
      Scene new_scene = create_scene(row);
      scenes.add(new_scene);
      if (max_total_people < new_scene.total) {
        max_total_people = new_scene.total;
      }
    } else {
      for (Scene scene: scenes) {
        if(scene.name == parent && scene.year == year) {
          Scene new_child_scene = create_scene(row);
          scene.add_child_scene(new_child_scene);
        }
      }
    }
  }
  
  active_scene = scenes.get(0);
}

Scene create_scene(TableRow row) {
  Scene scene = new Scene(row.getInt("ID"));
  scene.set_name(row.getString("NAME"));
  scene.set_parent(row.getString("PARENT"));
  scene.set_year(row.getInt("YEAR"));
  scene.set_total(row.getInt("TOTAL"));
  scene.set_increase(row.getInt("INCREASE"));
  scene.set_migration(row.getInt("MIGRATION"));
  scene.set_change(row.getInt("CHANGE"));

  return scene;
}

void set_active_scene(int index) {
 active_scene = scenes.get(index);
 process_active_scene_data();
}

void get_dots() {
  for(int row = 0; row <= rows; row = row + 1)  { // // row = vertikālais daudzums
    for (int col = 0; col <= columns; col = col + 1) { // col = horizontālais daudzums
      int x = parseInt(offset + (default_radius * 2 + space) * col); // horizontālais atstatums
      int y = parseInt(offset + (default_radius * 2 + space) * row); // vertikālais` atstatums
      int z = 1;
      
      PVector pos = new PVector(x , y, z);

      if(latvia_map_img.width < pos.x || latvia_map_img.height - 30 < pos.y) continue;

      int alpha = get_coord_alpha_value(latvia_map_img, x, y);
      if (alpha < 100) {
        dots.add(new Dot(alpha, pos, default_radius));
      }
    }
  }
}


void draw() {
  background(#000000);
  draw_dots();

  draw_labels();
}

void draw_labels() {
  camera.beginHUD(); // start drawing relative to the camera view
  fill(255);
  rect(20, 10, 120, 30);
  fill(0);
  text(str(frameRate), 30, 30);
  camera.endHUD();  // and don't forget to stop/close with this!
}


void process_active_scene_data() {
  boolean remove = (active_scene.change < 0);
  int changable_dots = abs(parseInt(active_scene.change) / parseInt(people_per_dot));
  println("changable_dots "+ changable_dots);
  
  while (changable_dots > 0) {
    int dot_index = parseInt(random(0, dots.size()));
    boolean decrease = false;
    if(remove) {
      if (!dots.get(dot_index).disapear) {
        dots.get(dot_index).disapear = true;
        decrease = true;
        //println("disapear "+ dots.get(dot_index).disapear);
      }
    } else {
      if( dots.get(dot_index).reapear ) {
        // TODO: get disapear list
        dots.get(dot_index).reapear = true;
        decrease = true;
      }
    }
    
    if (decrease) changable_dots --;
  }
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


void drawSphere(PVector pos, int radius) {
  // draws a sphere at x,y,z with size sizeSphere
  pushMatrix();
  noStroke();
  fill(#ffffff);
  translate(pos.x, pos.y, pos.z);
  sphereDetail(sphere_detail_nr);
  sphere(radius);
  popMatrix();
}


class Scene {
  public int id;
  public int year;
  public String name;
  public String parent;

  public int total;
  public int increase;
  public int migration;
  public int change;

  ArrayList<Scene> child_scenes = new ArrayList<Scene>();

  Scene(int id) {
    this.id = id;
  }

  void set_name(String name) {
    this.name = name;
  }

  void set_parent(String parent) {
    this.parent = parent;
  }

  void set_year(int year) {
    this.year = year;
  }

  void set_total(int total) {
    this.total = total;
  }

  void set_increase(int increase) {
    this.increase = increase;
  }

  void set_migration(int migration) {
    this.migration = migration;
  }

  void set_change(int change) {
    this.change = change;
  }

  void add_child_scene(Scene child_scene) {
    child_scenes.add(child_scene);
  }
}


class Dot {
  public int alpha;
  public int x;
  public int y;
  public int z;

  public PVector orignal;
  public PVector pos;
  public PVector target;

  public int radius;
  public boolean disapear = false;
  public boolean reapear = false;
  public boolean animation_done = true;
  Ani zDisapear;
  Ani zAppear;
  
  float duration = random(7, 20);
  float the_delay = random(0, 10);
  

  Dot(int a, PVector pos, int r) {
    this.alpha = a;
    this.orignal = pos;
    this.pos = pos;
    this.radius = r;
    this.x = parseInt(pos.x);
    this.y = parseInt(pos.y);
    this.z = parseInt(pos.z);
  }
  
  public void z_startup_position() {
    switch (z_animation) {
     case 1:
       this.pos.z = random(1, z_random_distance);
     break;
     default:
       //do nothing
    }
  }

  public void draw() {
    if (!this.disapear && !this.reapear) z_startup_position();
    if(this.disapear && animation_done) this.disapear();
    else if(this.reapear) this.reapear();
    
    // draws a sphere at x,y,z with size sizeSphere
    pushMatrix();
    noStroke();
    
    if (disapear && animation_done ) fill(#000000);
    else fill(#ffffff);
    
    translate(x, y, z);
    sphereDetail(sphere_detail_nr);
    sphere(radius);
    popMatrix();
  }

  public void disapear() {
    this.disapear = true;
    this.animation_done = false;
    this.target = new PVector(this.pos.x, this.pos.y, 3000);
    zDisapear = new Ani(this, duration, the_delay, "z", target.z, Ani.EXPO_IN_OUT, "onEnd:finish_anim");
  }

  public void reapear() {
    this.reapear = true;
    this.disapear = false;
    this.zAppear = new Ani(this, duration, 1, "z", this.target.z, Ani.ELASTIC_IN);
  }
  
  void finish_anim(Ani anim) {
    this.pos = this.target;
    this.x = parseInt(this.target.x);
    this.y = parseInt(this.target.y);
    this.z = parseInt(this.target.z);
    this.animation_done = true;
  }
}
