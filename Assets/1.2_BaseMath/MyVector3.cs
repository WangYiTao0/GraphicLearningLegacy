using UnityEngine;

namespace _1._2_BaseMath
{
    public struct MyVector3
    {
        public float x;
        public float y;
        public float z;

        public MyVector3(float _x, float _y, float _z)
        {
            x = _x;
            y = _y;
            z = _z;
        }
        
        public float magnitude
        {
            get
            {
                return Mathf.Sqrt( x * x + y * y + z * z);
            }
        }
        
        public static MyVector3 operator *(float k, MyVector3 v)
        {
            return new MyVector3(k* v.x, k*v.y, k * v.z);
        }
        
        public static MyVector3 operator *( MyVector3 v,float k)
        {
            return k * v;
        }
        
        public static MyVector3 operator /(MyVector3 v, float k )
        {
            return (1/k) * v;
        }
        
        public static MyVector3 operator +(MyVector3 a, MyVector3 b)
        {
            return new MyVector3(a.x + b.x, a.y + b.y, a.z * b.z);
        }
        
        public static MyVector3 operator -(MyVector3 a, MyVector3 b)
        {
            return new MyVector3(a.x - b.x, a.y - b.y, a.z - b.z);
        }

        public static float Distance(MyVector3 a, MyVector3 b)
        {
            return Mathf.Sqrt((a.x - b.x) * (a.x - b.x) +
                              (a.y - b.y) * (a.y - b.y) +
                              (a.z - b.z) * (a.z - b.z));
        }

        public MyVector3 normalized
        {
            get
            {
                return this*(1/this.magnitude);
            }
        }

        public void Normalize()
        {
            this = this.normalized;
        }

        
        public override string ToString()
        {
            return string.Format("{0:F2},{1:F2},{2:F2}",x,y,z);
        }

        public static float Dot(MyVector3 a, MyVector3 b)
        {
            return a.x * b.x + a.y * b.y + a.z * b.z;
        }

        public static float Project(MyVector3 a, MyVector3 n)
        {
            n.Normalize();
            return Dot(a, n);
        }

        public static MyVector3 Cross(MyVector3 a, MyVector3 b)
        {
            return new MyVector3(a.y * b.z - a.z * b.y, 
                a.z * b.x - a.x * b.z, 
                a.x * b.y - a.y * b.x);
        }
    }
}