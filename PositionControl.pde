import processing.serial.*;

import net.java.games.input.*;
import org.gamecontrolplus.*;
import org.gamecontrolplus.gui.*;

import cc.arduino.*;
import org.firmata.*;

ControlDevice cont;
ControlIO control;
Arduino arduino;

float Rot = 90;  //azimuthal servo prosition setting
float R = 70;    //radial position setting
float Z = 70;    //height position setting
float Jaw = 45;  //Jaw servo setting

float L1 = 135;  //Length of mainarm
float L2 = 147;  //Length of horarm
float maxLength = L1 + L2;  //Maximum length robot arm can extend

float mainarmServo;  //mainarm servo setting
float horarmServo;   //horarm servo setting

float RotAdjust = 0;  //adjustment values to be made to postion settings
float RAdjust = 0;    //taken from thumbstick inputs
float ZAdjust = 0;

int servoSpeed = 4;  //speed at which servos travel

// initize background for image, controller, and arduino
void setup() {
  size(800, 550);
  control = ControlIO.getInstance(this);
  cont = control.getMatchedDevice("xboxServo");
  
  if (cont == null) {
    println("no controller detected"); // write better exit statements than me
    System.exit(-1);
  }
  
  // println(Arduino.list());
  arduino = new Arduino(this, Arduino.list()[0], 57600);
  
  arduino.pinMode(3, Arduino.SERVO);
  arduino.pinMode(5, Arduino.SERVO);
  arduino.pinMode(9, Arduino.SERVO);
  arduino.pinMode(11, Arduino.SERVO);
}

// main loop, collect data from functions and write to servos via arduino
void draw() {
  background(0,0,0);
  getUserInput();
  findThetas(); 
  drawGraph(50,50);
  drawValues(510,90);
  drawSideProfile(120,470);
  drawTopProfile(600,470);
  textSize(12);
  text("all units in mm",650,530);
  
   
  arduino.servoWrite(3, (int)Rot);
  arduino.servoWrite(5, (int)mainarmServo);
  arduino.servoWrite(9, (int)horarmServo);
  arduino.servoWrite(11, (int)Jaw);
  
  //print various values for troubleshooting
  //println(Rot, mainarmServo, horarmServo, Jaw);
}

//------------------------------------------------------------------------
//retrieve inputs from xbox controller and use said inputs to adjust postition values of robot arm
public void getUserInput() {
  RotAdjust = map(deadzone(cont.getSlider("servoRot").getValue()), -1, 1, -servoSpeed, servoSpeed); // Read from controller and write to adjust variable
  if ((RotAdjust > 0)&&(Rot + RotAdjust >= 180)){RotAdjust = 0; Rot = 180;}                    // Check if servo is at upper limit (180)
  else if ((RotAdjust < 0)&&(Rot + RotAdjust <= 0)){RotAdjust = 0; Rot = 0;}                  // Check if servo is at lower limit (0)
  else {Rot = Rot + RotAdjust;}                                                                //Write adjust value to servo

  
  RAdjust = map(deadzone(cont.getSlider("servoHeight").getValue()), -1, 1, servoSpeed, -servoSpeed);  // Read from controller and write to adjust variable
  if (sqrt(R*R + Z*Z) >= (maxLength - 10)){RAdjust = -1;}                    // Check if arm is at the maximum length in radial direction
  else if (R <= 4){RAdjust = +1;}                  // Check if servo is at lower limit (4)
  R = R + RAdjust;
  
  ZAdjust = map(deadzone(cont.getSlider("servoLength").getValue()), -1, 1, servoSpeed, -servoSpeed);
  if (sqrt(R*R + Z*Z) >= (maxLength - 10)){ZAdjust = -1;}                    // Check if servo is at upper limit in height direction
  else if (Z <= -50){ZAdjust = +1;}                  // Check if servo is at lower limit (-50)
  Z = Z + ZAdjust;
  
  Jaw = map(cont.getSlider("servoJaw").getValue(), -1, 0, 0, 90);  //actuate Jaw
  if(Jaw > 90){         //ignore values from left trigger (90-180)
    Jaw = 90;
  }
  delay(20);
}

// Translate radial and azimuthal coordinates to angle values for the mainarm and horarm servos and keeps servos in limit
public void findThetas(){  
float D = sqrt(R*R + Z*Z);  // distance between base and desired destination point
float d1 = degrees(atan(Z/R));  //angle between destination point vector and the xy plane
float d2 = degrees(acos((L1*L1 + D*D - L2*L2)/(2*L1*D)));  //angle between the mainarm and the destination vector
float theta1 = (d1+d2);  //angle for the mainarm servo
float theta2 = degrees(acos((L1*L1 + L2*L2 - D*D)/(2*L1*L2)));  //angle between the mainarm and horarm

mainarmServo = 170 - theta1;  //ofset adjustment of servo  
if (mainarmServo >= 150){mainarmServo = 150;}  //ensure servo doesn't exceed limits
else if (mainarmServo <= 60){mainarmServo = 60;}

horarmServo = theta2 + theta1 - 30;  //translate from angle between arms to angle between horarm and radial plane
if (horarmServo >= 170){horarmServo = 170;}  ////ensure servo doesn't exceed limits
else if (horarmServo <= 70){horarmServo = 70;}
}

// if thumbstick values are between -0.15 and 0.15, write 0 to prevent servo drift
float deadzone(float val){
  if ((val < 0.15)&&(val > -0.15)){val = 0;}  
  return val;
}

//draw servo position graph with offset in draw environment x and y
void drawGraph(int gx, int gy){  
  textSize(16);
  strokeWeight(0);
  fill(0,200,0);
  text("Servo Values",gx+100,gy-20); //title
  textSize(10);
  //y scale
  text("0",gx,gy+180);  
  text("90",gx,gy+90);
  text("180",gx,gy);
  
  //draw servo position bars
  drawBar(gx+30,gy,(int)Rot,"Rotation Servo");
  drawBar(gx+130,gy,(int)mainarmServo,"Mainarm Servo");
  drawBar(gx+230,gy,(int)horarmServo,"Horarm Servo");
  drawBar(gx+330,gy,(int)Jaw,"Jaw Servo");
}

//draw a vertical bar graph (x postiton, y position, servo value, bar name)
void drawBar(int x, int y, int value, String name){
  rect(x,y + 180,80,-value);
  text(name, x, y + 200);
}

//draw robat arm side profile at position x and y
void drawSideProfile(int x, int y){
  strokeWeight(1);
  stroke(150,150,150);
  textSize(18);
  text("Side Profile",x+40,y-180); //title
  textSize(10);
  //draw horizontal lines
  for(int i = 50; i >= -175; i = i - 25){
    line(x-50,y+i,x+300,y+i);
    if(i % 50 == 0){text(i,x-80,y+i+5);}  // label at 50mm increments
  }   
  //draw vertical lines
  for(int i = 50; i >= -300; i = i - 25){
    line(x-i,y+50,x-i,y-175);
    if(i % 50 == 0){text(i,x-i,y+65);} // label at 50mm increments
  }
  
  strokeWeight(10);
  fill(0,200,0);
  stroke(0,200,0);
  
  //calculate endpoint of mainarm (x1 and y1) and draw mainarm
  int x1 = (int)(L1*cos(radians(-mainarmServo-10)));
  int y1 = (int)(L1*sin(radians(-mainarmServo-10)));
  line(x,y,(x-x1), y + y1);
  
  //calculate endpoint of horarm (x2 and y2) and draw horarm
  int x2 = (int)(L2*cos(radians(horarmServo+30)))+x1;
  int y2 = (int)(L2*sin(radians(horarmServo+30)))+y1;
  line(x-x1,y+y1,x-x2,y+y2);
  
  //line to represent Jaw
  line(x-x2,y+y2,x-x2+40-0.1*Jaw,y+y2);
  
  //shapes for base
  rect(x-50,y+15,70,30);
  ellipse(x,y+15,30,30);
}

//draw top profile of robot arm
void drawTopProfile(int x, int y){
  strokeWeight(1);
  noFill();
  stroke(150,150,150);
  textSize(18);
  text("Top Profile",x-50,y-180);
  textSize(10);
  
  //draw arcs
  for(int i = 50; i <= 300; i = i + 50){
  arc(x,y,i,i,-PI,0);
  text(i*2,x+i-5,y+15);
  }
  
  //draw angle lines
  line(x-150,y,x+150,y);
  line(x,y,x,y-150);
  line(x,y,x+sqrt(2)/2*150,y-sqrt(2)/2*150);
  line(x,y,x-sqrt(2)/2*150,y-sqrt(2)/2*150);
  
  stroke(0,200,0);
  strokeWeight(10);
  
  int x0 = (int)(L1*cos(radians(-mainarmServo-10)));  //calculate length of mainarm viewed from above
  int armLength = (int)(((L2*cos(radians(horarmServo+30)))+x0)*0.5);  //calculate total length of arm when viewed from above
  int theta = (int)(0.5*Rot+45);  //azimuthal angle
  int x1 = (int)(armLength*cos(radians(theta)));  //x coordinate endpoint of arm
  int y1 = (int)(armLength*sin(radians(theta)));  //y coordinate endpoint of arm
  
  line(x,y,x+x1,y+y1); //arm of robot
  rect(x-5,y-5,10,20);  //base of robot
}

//draw postiton values requested by user
void drawValues(int x, int y){
  textSize(18);
  strokeWeight(1);
  fill(0,200,0);
  
  text("Requested Postition Values",x,y-60); //title
  textSize(16);
  //names of values
  text("azimuthal:",x,y);
  text("radial:",x, y+20);
  text("height:",x,y+40);
  text("Jaw:",x,y+60);
  
  //values themselves
  text((int)(0.5*Rot+45),x+100,y);
  text((int)R,x+100,y+20);
  text((int)Z,x+100,y+40);
  text((int)(100-Jaw*10/9),x+100,y+60);
}
