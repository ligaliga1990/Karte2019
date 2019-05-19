
Table table;
String [][] test = new String[30][7];


void setup() {
  fullScreen();
  //size (600,600); 

  table = loadTable("Latvijasdatieksports.csv", "header"); // sketch mapē ir dati saglabāti csv failā, kas ar notepad ir pārveidots, lai visu atdala komati

  println(table.getRowCount() + " total rows in table");
  //println ();
  
}
void draw() {
background (0);
  noStroke ();
  for(int i = 0; i <= 150; i = i + 1)  { // // skaitlis = horizontālais daudzums
    for (int j = 0; j < 80; j = j+1) { // skaitlis ir vertikālais daudzums 
      
    float x = 5 + i*10; // horizontālais atstatums
    float s = 5 + i*0;
    float x2 = 5 + j*10; // vertikālais` atstatums
    float s2 = 5 + j*0;
    
    fill(255);
    ellipse(x, x2,s,s2);
    {
   
    }
    } 
    } 
        


}
