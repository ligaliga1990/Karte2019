import peasy.org.apache.commons.math.*;
import peasy.*;
import peasy.org.apache.commons.math.geometry.*;

import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;


PeasyCam camera;
Table table;
PImage latvia_map_img;

int DISPLAY_NR = 1;

//
String data_regions = "data/regions.csv";
String data_population = "data/population.csv";


// app settings
float app_width;
float app_height;
int rows;
int columns;
int active_scene_index = 0;
Scene active_scene;

// sphere data and offsets
int default_radius = 4;
float space = default_radius * 2;
float offset = default_radius * 2;
int sphere_detail_nr = 20;


int next_scene_interval = 60 * 1000; // 60 sec
int max_total_people;
int people_per_dot;


ArrayList<Region> regions = new ArrayList<Region>();
ArrayList<Dot> dots = new ArrayList<Dot>();
ArrayList<Scene> scenes = new ArrayList<Scene>();
ArrayList<Label> labels = new ArrayList<Label>();


void setup() {
  fullScreen(P3D, DISPLAY_NR);

  // Ani.init() must be called always first!
  Ani.init(this);

  // Define screen dimensions with offset
  app_width = displayWidth - offset;
  app_height = displayHeight - offset;

  println("Screen Size width: " + app_width);
  println("Screen Size height: " + app_height);

  // Add 3D world camera
  camera = new PeasyCam(this, displayWidth / 2, displayHeight / 2, 0, 1000);
  camera.setMinimumDistance(400);
  camera.setMaximumDistance(displayWidth * 3);

  calculate_rows();
  calculate_columns();

  load_regions_data();
  get_dots();
  load_scene_data();

  if (dots.size() > 0) people_per_dot = max_total_people / dots.size();
  int divider = 2;
  people_per_dot = people_per_dot / divider;

  println("dots: " + dots.size());
  println("max total people: " + max_total_people);
  println("peopel per dot: " + people_per_dot);

  println("peopel per dot diveded by " + divider + ": " + people_per_dot);
  set_active_scene(0);
  load_labels();
}

void load_labels() {
  labels.add(new Label("", LABEl_TYPE.YEAR));
  create_regions_labels(regions);
  for(int index = 0; index < labels.size(); index++) {
    labels.get(index).set_pos(new PVector(width / labels.size() * index + 10, height - 50));
  }
  println("labels count: " + labels.size());
}

void create_regions_labels(ArrayList<Region> p_regions) {
  for(Region region: p_regions) {
    labels.add(new Label(region.label, LABEl_TYPE.REGION, region));
    if (region.child_regions.size() > 0) {
      create_regions_labels(region.child_regions);
    }
  }
}



void load_regions_data() {
  println("==> Load regions data:");
  table = loadTable(data_regions,"header"); // sketch mapē ir dati saglabāti csv failā, kas ar notepad ir pārveidots, lai visu atdala komati
  int columns = table.getColumnCount();
  int rows = table.getRowCount();

  println(rows + " total rows in regions table");
  println(columns + " total columns in regions table");

  for (TableRow row : table.rows()) {
    String name = trim(row.getString("NAME"));
    String parent = new String(trim(row.getString("PARENT")));
    String label = row.getString("LABEL");
    String color_code = row.getString("COLOR");
    String image = trim(row.getString("IMAGE"));

    Region new_region = create_region(row);

    if (parent.length() == 0) {
      regions.add(new_region);
    } else {
      ArrayList<Region> parent_array = find_parent_region(regions, parent);
      if (parent_array.size() > 0) {
        parent_array.get(0).child_regions.add(new_region);
      }
    }
  }
}


ArrayList<Region> find_parent_region(ArrayList<Region> passed_regions, String parent_name) {
  ArrayList<Region> returnable = new ArrayList<Region>();
  for (Region region: passed_regions) {
    if(region.name.equals(parent_name)) {
      returnable.add(region);
      return returnable;
    } else if (region.child_regions.size() > 0) {
      return find_parent_region(region.child_regions, parent_name);
    }
  }

  return returnable;
}



void load_scene_data() {
  println("==> Load population data:");
  table = loadTable(data_population,"header"); // sketch mapē ir dati saglabāti csv failā, kas ar notepad ir pārveidots, lai visu atdala komati

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
        if(scene.name.equals(parent) && scene.year == year) {
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
  scene.set_name(new String(trim(row.getString("NAME"))));
  scene.set_parent(new String(trim(row.getString("PARENT"))));
  scene.set_year(row.getInt("YEAR"));
  scene.set_total(row.getInt("TOTAL"));
  scene.set_increase(row.getInt("INCREASE"));
  scene.set_migration(row.getInt("MIGRATION"));
  scene.set_change(row.getInt("CHANGE"));

  return scene;
}

Region create_region(TableRow row) {
  Region region = new Region(row.getInt("ID"));


  region.set_name(new String(trim(row.getString("NAME"))));
  region.set_parent(new String(trim(row.getString("PARENT"))));
  region.set_label(new String(trim(row.getString("LABEL"))));
  region.set_image(new String(trim(row.getString("IMAGE"))));


  color color_code = color(unhex(trim(row.getString("COLOR")))) | 0xff000000;
  region.set_color(color_code);

  return region;
}

void set_active_scene(int index) {
  active_scene_index = index;
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

      boolean skip = false;
      int should_be_added = 1;

      for (Region region: regions) {
        if(region.image.width < pos.x || region.image.height - 30 < pos.y) {
          break;
        }
        int g_alpha = get_coord_alpha_value(region.image, parseInt(pos.x), parseInt(pos.y));
        if (g_alpha < 100) {
          int return_code = process_region_dots(region, pos);

          if (return_code != 0) {
            Dot dot = new Dot(g_alpha, pos, default_radius, region.name);
            dot.set_color(region.color_code);
            dots.add(dot);
          }
        }
      }

      if (skip) continue;
    }
  }
}

int process_region_dots(Region region, PVector pos) {
  if (region.child_regions.size() > 0) {
    int return_code = 0;
    for (Region child_region: region.child_regions) {
      return_code = process_region_dots(child_region, pos);

      if (return_code == 0) return return_code;
    }
  } else {
    if(region.image.width < pos.x || region.image.height - 30 < pos.y) {
      return 1;
    }

    int alpha = get_coord_alpha_value(region.image, parseInt(pos.x), parseInt(pos.y));

    if (alpha < 100) {
      Dot dot = new Dot(alpha, pos, default_radius, region.name);
      dot.set_color(region.color_code);
      dots.add(dot);

      return 0;
    }
  }
  return 3;
}


void draw() {
  background(#000000);
  draw_dots();
  draw_labels();
}

void draw_labels() {
  camera.beginHUD(); // start drawing relative to the camera view
  // fill(0);
  // rect(0, height - 100, width, 100);
  fill(255);

  for (Label label : labels) {
    label.draw();
  }

  camera.endHUD();  // and don't forget to stop/close with this!
}


void process_active_scene_data() {
  boolean remove = (active_scene.change < 0);
  int changable_dots = abs(parseInt(active_scene.change) / parseInt(people_per_dot));

  println("total changable dots: " + changable_dots);

  for( Scene child_scene: active_scene.child_scenes) {
    boolean child_remove = (child_scene.change < 0);
    int child_changable_dots = abs(parseInt(child_scene.change) / parseInt(people_per_dot));

    String child_region_name = child_scene.name;

    ArrayList<Dot> child_dots = new ArrayList<Dot>();
    ArrayList<Dot> disapearable_child_dots = new ArrayList<Dot>();
    ArrayList<Dot> reapearable_child_dots = new ArrayList<Dot>();


    for (Dot dot: dots) {
      if (dot.region_name.equals(child_region_name)) {
        child_dots.add(dot);

        if (dot.disapear == 0 ) {
          disapearable_child_dots.add(dot);
        }

        if (dot.disapear != 0 && dot.reapear == 0) {
          reapearable_child_dots.add(dot);
        }
      }
    }

    int changed_dots = 0;
    int available_changable_dots = disapearable_child_dots.size() + reapearable_child_dots.size();

    while (child_changable_dots > 0) {
      if (disapearable_child_dots.size() == 0 && reapearable_child_dots.size() == 0 ) break;
      if (available_changable_dots == changed_dots) break;

      boolean decrease = false;

      if(child_remove) {
        int dot_index = parseInt(random(0, disapearable_child_dots.size()));
        if (disapearable_child_dots.get(dot_index).disapear == 0) {
          child_dots.get(dot_index).disapear = 1;
          decrease = true;
        }
      } else {
        int dot_index = parseInt(random(0, reapearable_child_dots.size()));
        if( child_dots.get(dot_index).reapear == 0) {
          // TODO: get disapear list
          child_dots.get(dot_index).reapear = 1;
          decrease = true;
        }
      }

      if (decrease) {
        child_changable_dots --;
        changed_dots ++;
      }
    }

    changable_dots = changable_dots - changed_dots;
  }

  while (changable_dots > 0) {
    int dot_index = parseInt(random(0, dots.size()));
    boolean decrease = false;
    if(remove) {
      if (dots.get(dot_index).disapear == 0) {
        dots.get(dot_index).disapear = 1;
        decrease = true;
        //println("disapear "+ dots.get(dot_index).disapear);
      }
    } else {
      if( dots.get(dot_index).reapear  == 0) {
        // TODO: get disapear list
        dots.get(dot_index).reapear = 1;
        decrease = true;
      }
    }

    if (decrease) changable_dots --;
  }

  active_scene.start();
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

void load_next_scene() {
  int next_active_scene_index =  active_scene_index + 1;
  if (next_active_scene_index > scenes.size() - 1) {
    next_active_scene_index = 0;
  }
  set_active_scene(next_active_scene_index);
}

void draw_dots() {
  // The second is using an enhanced loop:
  ambientLight(255, 255, 255);
  boolean go_to_next_scene = true;
  for (Dot dot : dots) {
    dot.draw();
    if(!dot.animation_done) go_to_next_scene = false;
  }

  if (millis() > active_scene.end_time) go_to_next_scene = true;

  if (go_to_next_scene) {
    load_next_scene();
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


interface LABEl_TYPE {
  int
  YEAR         = 0,
  REGION       = 1;
}


class Label {
  String label;
  Region region;
  String previous_text;
  String text;
  int type;
  boolean pos_set = false;
  PVector pos;
  color color_code;

  Label(String label, int type, Region region) {
    this.label = label;
    this.type = type;
    this.region = region;
    this.color_code = region.color_code;
  }

  Label(String label, int type) {
    this.label = label;
    this.type = type;
    this.color_code = #ffffff;
  }

  void set_pos(PVector pos) {
    this.pos = pos;
    this.pos_set = true;
  }

  String get_text() {
    switch(type) {
      case LABEl_TYPE.YEAR:
        return str(active_scene.year);
      case LABEl_TYPE.REGION:
        if (active_scene.name.equals(this.region.name)) {
          return str(active_scene.total);
        } else {
          for (Scene scene: active_scene.child_scenes) {
            if (scene.name.equals(this.region.name)) {
              return str(scene.total);
            }
          }
        }
    }

    if (type == LABEl_TYPE.YEAR) {
      return str(active_scene.year);
    } else
    return "";
  }

  void draw() {
    this.previous_text = this.text;
    this.text = get_text();

    if (this.pos_set) {
      textSize(18);
      fill(this.color_code);
      text(this.label + " " + this.text, this.pos.x, this.pos.y);
    }
  }
}

class Region {
  int id;
  String name;
  String label;
  String parent;
  color color_code;

  String image_path;
  PImage image;

  Label label_object;


  ArrayList<Region> child_regions = new ArrayList<Region>();

  Region(int id) {
    this.id = id;
  }

  // void create_label(int number) {
  //   Label label_object.update(this.label + " " + new String(number));
  // }

  void set_name(String name) {
    this.name = name;
  }

  void set_parent(String parent) {
    this.parent = parent;
  }

  void set_label(String label) {
    this.label = label;
  }

  void set_color(color color_code) {
    this.color_code = color_code;
  }

  void set_image(String image_path) {
    this.image_path = image_path;


    this.image = loadImage(image_path);
    this.image.resize(displayWidth, displayHeight);

    println("Image " + this.image_path + " width: " + this.image.width);
    println("Image " + this.image_path + "  height: " + this.image.height);
  }

  void add_child_scene(Region child_region) {
    child_regions.add(child_region);
  }
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
  public int end_time;

  ArrayList<Scene> child_scenes = new ArrayList<Scene>();

  Scene(int id) {
    this.id = id;
  }

  void start() {
    this.end_time = millis() + scene_interval;
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

  public String region_name;

  public PVector orignal;
  public PVector pos;
  public PVector target;

  public int radius;
  public int disapear = 0;
  public int reapear = 0;
  public boolean animation_done = true;

  public color color_code;

  Ani zAnim;

  float duration = random(5, 20);
  float the_delay = random(0, 5);


  Dot(int a, PVector pos, int r, String region_name) {
    this.alpha = a;
    this.orignal = pos;
    this.pos = pos;
    this.radius = r;
    this.x = parseInt(pos.x);
    this.y = parseInt(pos.y);
    this.z = parseInt(pos.z);
    this.color_code = #FFFFFF;

    this.region_name = region_name;
  }

  public void set_color(color color_code) {
    this.color_code = color_code;
  }

  public void z_startup_position() {
    switch (z_animation) {
      case 1:
        this.z = parseInt(random(-z_random_distance, z_random_distance));
        this.pos.z = this.z;
      break;
      default:
       //do nothing
    }
  }

  public void draw() {
    if (this.disapear == 0 && this.reapear == 0) z_startup_position();
    if(this.disapear == 1 && animation_done) this.disapear();
    else if(this.reapear == 1 && animation_done) this.reapear();

    // draws a sphere at x,y,z with size sizeSphere
    pushMatrix();
    noStroke();

    if (this.disapear == 2 && this.animation_done )
      fill(this.color_code, alpha(255));
    else if (this.disapear == 1) {
      int map_v = parseInt(map(z, 0, 1500, 255, 0));
      //println("z: " + z + " map: " + map_v );
      fill(this.color_code, map_v);
    } else if (this.reapear == 1) {
      int map_v = parseInt(map(z, 1500, 0, 0, 255));
      //println("z: " + z + " map: " + map_v );
      fill(this.color_code, map_v);
    } else
      fill(this.color_code);

    translate(this.x, this.y, this.z);
    sphereDetail(sphere_detail_nr);
    sphere(radius);
    popMatrix();
  }

  public void disapear() {
    this.reapear = 0;
    this.disapear = 1;
    this.animation_done = false;
    this.target = new PVector(this.pos.x, this.pos.y, 1500);
    zAnim = new Ani(this, duration, the_delay, "z", target.z, Ani.QUAD_OUT, "onEnd:finish_anim");
  }

  public void reapear() {
    this.reapear = 1;
    this.disapear = 0;
    zAnim = new Ani(this, duration, the_delay, "z", orignal.z, Ani.QUAD_OUT, "onEnd:finish_anim");
  }

  void finish_anim(Ani anim) {
    this.pos = this.target;
    this.x = parseInt(this.target.x);
    this.y = parseInt(this.target.y);
    this.z = parseInt(this.target.z);
    this.animation_done = true;

    if(disapear == 1) this.disapear = 2;
    else if(reapear == 1) this.reapear = 2;
  }
}
