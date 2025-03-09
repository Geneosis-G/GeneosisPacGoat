class PacHelper extends Actor;

var ParticleSystemComponent lightRayPSC;
var ParticleSystem lightRayPSTemplate;
var PacFood mHelpingItem;

event PostBeginPlay()
{
	super.PostBeginPlay();

	SetPhysics(PHYS_None);
	CollisionComponent=none;
	lightRayPSC=WorldInfo.MyEmitterPool.SpawnEmitter(lightRayPSTemplate, Location, Rotation, self);
	lightRayPSC.SetScale3D(vect(1.f, 1.f, 8.f));
	//lightRayPSC.CustomTimeDilation=0.1f;
	lightRayPSC.ActivateSystem();
}

function AttachHelper(PacFood food)
{
	mHelpingItem = food;
	SetLocation(food.Location);
	SetHidden(false);
}

function DetachHelper()
{
	mHelpingItem = none;
	SetLocation(vect(0, 0, 0));
	SetHidden(false);
}

simulated event Destroyed()
{
	lightRayPSC.DeactivateSystem();
	lightRayPSC.KillParticlesForced();

	Super.Destroyed();
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true
	lightRayPSTemplate=ParticleSystem'Space_Particles.Particles.Teleporter_Squares'
}