using System;
using UnityEngine;

public class CameraRotation : MonoBehaviour
{
    [SerializeField] private Transform _target;
    [SerializeField] private float _rotateSpeed = 60f;
    private void Update()
    {
        if (transform.position.z < _target.position.z)
        {
            _rotateSpeed *= -1;
        }
        transform.RotateAround(_target.position,_target.up,_rotateSpeed * Time.deltaTime);
    }
}
