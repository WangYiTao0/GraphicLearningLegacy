using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class MathTest : MonoBehaviour
{
    [SerializeField] private GameObject _prefab;
    void Start()
    {
        var points = MathPosition.GenerateArchimedeanSpirals(400,
        transform.position, 6,0.2f,0.5f);

        for (int i = 0; i < points.Length; i++)
        {
            Instantiate(_prefab, points[i], Quaternion.identity, transform);
        }
    }

    void Update()
    {
        
    }
}
