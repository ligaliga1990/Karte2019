import peasy.org.apache.commons.math.*;
import peasy.*;
import peasy.org.apache.commons.math.geometry.*;

import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;


PeasyCam camera;
Table table;
PImage latvia_map_img;

int DISPLAY_NR = 0;

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

long max_total_people;
long people_per_dot;

final int label_year_x = 20;
final int label_year_y = 1000;
final int label_year_font_size = 18;

Ani global;

boolean reset = false;




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
  set_active_scene(0, false);
  load_labels();
}


void load_labels() {
  labels.add(new Label("", LABEl_TYPE.YEAR));
  create_regions_labels(regions);
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
    long total = Long.parseLong(row.getString("TOTAL"));


    if (parent.length() == 0) {
      Scene new_scene = create_scene(row);
      scenes.add(new_scene);
      if (max_total_people < total) {
        max_total_people = total;
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

Scene create_scene(TableRow p_row) {
  Scene scene = new Scene(p_row.getInt("ID"));

  scene.set_name(new String(trim(p_row.getString("NAME"))));
  scene.set_parent(new String(trim(p_row.getString("PARENT"))));
  scene.set_year(p_row.getInt("YEAR"));
  scene.set_total(p_row.getString("TOTAL"));

  return scene;
}

Region create_region(TableRow row) {
  Region region = new Region(row.getInt("ID"));


  region.set_name(new String(trim(row.getString("NAME"))));
  region.set_parent(new String(trim(row.getString("PARENT"))));
  region.set_label(new String(trim(row.getString("LABEL"))));
  region.set_image(new String(trim(row.getString("IMAGE"))));

  int label_x = row.getInt("LABEL_X");
  int label_y = row.getInt("LABEL_Y");
  int font_size = row.getInt("FONT_SIZE");
  region.set_label_position(label_x, label_y, font_size);


  color color_code = color(unhex(trim(row.getString("COLOR")))) | 0xff000000;
  region.set_color(color_code);

  return region;
}

void set_active_scene(int index, boolean reset) {
  long previous_total = 0;
  if (reset)
    previous_total = scenes.get(index).total;
  else
    previous_total = active_scene.total;

  active_scene_index = index;
  println("scene " + scenes.get(index));
  active_scene = scenes.get(index);

  process_active_scene_data(previous_total, reset);
}

void get_dots() {
  for(int row = 0; row <= rows; row = row + 1)  { // // row = vertikālais daudzums
    for (int col = 0; col <= columns; col = col + 1) { // col = horizontālais daudzums
      int x = parseInt(offset + (default_radius * 2 + space) * col); // horizontālais atstatums
      int y = parseInt(offset + (default_radius * 2 + space) * row); // vertikālais` atstatums
      int z = 1;

      PVector pos = new PVector(x, y, z);

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

  for (Label label : labels) {
    label.draw();
  }

  camera.endHUD();  // and don't forget to stop/close with this!
}


void process_active_scene_data(long previous_total, boolean reset) {
  println("process_active_scene_data");
  long change = active_scene.total - previous_total;
  long changable_dots = Long.parseLong(str(parseInt(abs(change / people_per_dot))));
  boolean remove = (change < 0);

  //println("total changable dots: " + changable_dots);

  if (! reset) {
    for( Scene child_scene: active_scene.child_scenes) {
      boolean child_remove = (child_scene.change < 0);
      long child_changable_dots = Long.parseLong(str(parseInt(abs(child_scene.change / people_per_dot))));

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

      int timeout = millis() + 5000;
      while (child_changable_dots > 0 && timeout > millis()) {
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

    int timeout = millis() + 5000;
    while (changable_dots > 0 && timeout > millis()) {
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
  }
  println("active scene start");
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
  boolean reset = false;
  if (next_active_scene_index >= scenes.size()) {
    next_active_scene_index = 0;
    Ani.killAll();
    for (Dot dot : dots) {
      dot.reset();
      dot.draw();
    }

    reset = true;
  }
  println("active_scene_index: " + next_active_scene_index);
  set_active_scene(next_active_scene_index, reset);
}

void draw_dots() {
  // The second is using an enhanced loop:
  ambientLight(255, 255, 255);
  boolean go_to_next_scene = true;
  for (Dot dot : dots) {
    if (reset) dot.reset();
    dot.draw();
    //if(!dot.animation_done) go_to_next_scene = false;
  }

  if (reset) reset = false;

  if (millis() < active_scene.end_time) go_to_next_scene = false;

  if (go_to_next_scene) {
    load_next_scene();
  }
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
  int x;
  int y;
  int font_size;

  Label(String label, int type, Region region) {
    this.label = label;
    this.type = type;
    this.region = region;
    this.color_code = region.color_code;

    this.x = region.label_x;
    this.y = region.label_y;
    this.font_size = region.font_size;
    this.pos_set = true;

  }

  Label(String label, int type) {
    this.label = label;
    this.type = type;
    this.color_code = #ffffff;
    this.x = label_year_x;
    this.y = label_year_y;
    this.font_size = label_year_font_size;
    this.pos_set = true;
  }

  void set_pos(PVector pos) {
    this.pos = pos;
    this.pos_set = true;
  }

  int get_length() {
    String t = this.label;

    switch(type) {
      case LABEl_TYPE.YEAR:
        return t.length() + 5 * 18;
      case LABEl_TYPE.REGION:
        return t.length() + 20 * 10;

    }
    return 0;
  }

  String get_text() {
    switch(type) {
      case LABEl_TYPE.YEAR:
        return str(active_scene.year);
      case LABEl_TYPE.REGION:
        if (active_scene.name.equals(this.region.name)) {
          return active_scene.total_text;
        } else {
          for (Scene scene: active_scene.child_scenes) {
            if (scene.name.equals(this.region.name)) {
              return scene.total_text;
            }
          }
        }
    }
    return "";
  }

  void draw() {
    this.previous_text = this.text;
    this.text = get_text();

    if (this.pos_set) {
      textSize(this.font_size);
      fill(this.color_code);
      text(this.label + " " + this.text, this.x, this.y);
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

  int label_x;
  int label_y;
  int font_size;


  ArrayList<Region> child_regions = new ArrayList<Region>();

  Region(int id) {
    this.id = id;
  }

  void set_label_position(int x, int y, int font_size) {
    this.label_x = x;
    this.label_y = y;
    this.font_size = font_size;
  }

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


    try {
      this.image = loadImage(image_path);
      this.image.resize(displayWidth, displayHeight);

      println("Image " + this.image_path + " width: " + this.image.width);
      println("Image " + this.image_path + "  height: " + this.image.height);
    }
    catch (NullPointerException error)
    {
      println("no file availible");
    }
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

  public long total;
  public String total_text;
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

  void set_total(String total) {
    this.total = Long.parseLong(total);
    this.total_text = total;
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
    this.target = this.pos;
    this.radius = r;
    this.x = parseInt(pos.x);
    this.y = parseInt(pos.y);
    this.z = parseInt(pos.z);
    this.color_code = #FFFFFF;

    this.region_name = region_name;
  }

  Dot(Dot object) {
    this.alpha = object.alpha;
    this.orignal = object.orignal;
    this.pos = object.pos;
    this.target = object.target;
    this.radius = object.radius;
    this.x = object.x;
    this.y = object.y;
    this.z = object.z;
    this.color_code = object.color_code;

    this.region_name = object.region_name;
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
    if(this.disapear == 1 && animation_done) this.decrease();
    else if(this.reapear == 1 && animation_done) this.increase();

    // draws a sphere at x,y,z with size sizeSphere
    strokeWeight(radius * 2);

    stroke(this.color_code);
    fill(this.color_code);

    point(parseInt(this.orignal.x), parseInt(this.orignal.y), parseInt(this.orignal.z));
    line(
      this.orignal.x, this.orignal.y, this.orignal.z,
      parseFloat(this.x), parseFloat(this.y), parseFloat(this.z)
    );
  }

  public void reset () {
    this.target = this.orignal;
    this.pos = this.orignal;
    this.x = parseInt(this.orignal.x);
    this.y = parseInt(this.orignal.y);
    this.z = parseInt(this.orignal.z);
    this.disapear = 0;
    this.reapear = 0;
    this.animation_done = true;
  }

  public void increase() {
    this.reapear = 0;
    this.disapear = 1;
    this.animation_done = false;
    this.target = new PVector(this.pos.x, this.pos.y, this.pos.z + 40);

    zAnim = Ani.to(this, duration, the_delay, "z", target.z, Ani.QUAD_OUT, "onEnd:finish_anim");
  }

  public void decrease() {
    this.reapear = 1;
    this.disapear = 0;
    this.target = new PVector(this.pos.x, this.pos.y, this.pos.z - 40);
    zAnim = Ani.to(this, duration, the_delay, "z", target.z, Ani.QUAD_OUT, "onEnd:finish_anim");
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
