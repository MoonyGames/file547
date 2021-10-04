using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

[RequireComponent(typeof(CharacterController))]
[AddComponentMenu("Movement/Player Movement")]

public class playerMovement : MonoBehaviour
{
    #region Initialization and Variables

    [SerializeField] private Button crouchButton;
    [SerializeField] private float crouchedSpeed, walkSpeed;
    [SerializeField] private Animator animator;

    private enum playerStates
    {
        IDLE,
        Walk,
        Crouch,
        Caught,
    }

    private playerStates playerState;
    private CharacterController characterController;

    private Vector3 movement;
    private float speed = 0f;
    private bool isCrouched = false;

    private Vector3 gravity = new Vector3(0f, -9.81f, 0f);

    private void Awake()
    {
        characterController = GetComponent<CharacterController>();
    }

    private void Start()
    {
        playerState = playerStates.IDLE;
    }

    #endregion

    #region Player State Machine

    private void Update()
    {
        Gravity();

        if (SimpleInput.GetAxis("Horizontal") != 0 || SimpleInput.GetAxis("Vertical") != 0)
        {
            float deltaX = SimpleInput.GetAxis("Horizontal") * speed;
            float deltaZ = SimpleInput.GetAxis("Vertical") * speed;

            movement = new Vector3(deltaX, 0f, deltaZ);
            movement = Vector3.ClampMagnitude(movement, speed);
            movement *= Time.deltaTime;

            float rotationAngle = Mathf.Atan2(SimpleInput.GetAxis("Horizontal"), SimpleInput.GetAxis("Vertical")) * Mathf.Rad2Deg;
            transform.rotation = Quaternion.Lerp(transform.rotation, Quaternion.Euler(0f, rotationAngle, 0f), 4f * Time.deltaTime);

            if (!isCrouched)
            {
                speed = walkSpeed;

                playerState = playerStates.Walk;
            }
        }
        else if ((SimpleInput.GetAxis("Horizontal") == 0 && SimpleInput.GetAxis("Vertical") == 0) && !isCrouched) playerState = playerStates.IDLE;

        switch (playerState)
        {
            case playerStates.IDLE:
                speed = 0f;
                animatorIDLE();
                break;
            case playerStates.Walk:
                Walk(movement);
                animatorWalk();
                break;
            case playerStates.Crouch:
                Walk(movement);
                break;
            case playerStates.Caught:
                break;
            default:
                break;
        }
    }

    #endregion

    #region Actions and Events

    private void Walk(Vector3 movement)
    {
        characterController.Move(movement);
    }

    public void Crouch()
    {
        if (playerState != playerStates.Crouch)
        {
            animator.SetBool("Crouch", true);
            isCrouched = true;
            playerState = playerStates.Crouch;

            speed = crouchedSpeed;
        }
        else
        {
            isCrouched = false;
            animator.SetBool("Crouch", false);
        }
    }

    private void Gravity()
    {
        characterController.Move(gravity);
    }

    private void animatorIDLE()
    {
        animator.SetBool("Walk", false);
        animator.SetBool("Crouch", false);
    }

    private void animatorWalk()
    {
        animator.SetBool("Walk", true);
    }
    #endregion
}
