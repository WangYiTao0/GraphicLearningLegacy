using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class MathPosition
{
    public static Vector3[] GenerateArchimedeanSpirals(int points,Vector3 centre,int circles,float a,float b){

        Vector3[] coordinates=new Vector3[points]; 

        float radius;

        float theta=2f*Mathf.PI/points*circles;
        for(int t=0;t<points;t++){
    
            radius=a+b*theta;	

            coordinates[t]=new Vector3(radius*Mathf.Cos(theta)+centre.x,radius*Mathf.Sin(theta)+centre.y,0f);
            theta+=2f*Mathf.PI/points*circles;
        }
        return coordinates;
    }
}
