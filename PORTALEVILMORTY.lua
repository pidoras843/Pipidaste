@name Портальная Пушка "Янтарь"
@inputs Button:wirelink ModeButton:wirelink
@outputs ColorR:number ColorG:number ColorB:number
@persist Mode:string PortalPos:vector PortalAng:angle IsFiring:number Timer:number

if (first()) {
    holoCreate(1, "models/props_c17/oildrum001.mdl", entity():pos(), ang(0,0,0))
    holoScale(1, vec(0.8, 0.8, 1.2))
    holoColor(1, vec(150, 130, 100))
    
    holoCreate(2, "models/props_c17/canister01a.mdl", entity():pos(), ang(0,0,0))
    holoScale(2, vec(0.5, 0.5, 0.3))
    holoColor(2, vec(80, 70, 60))
    
    holoCreate(3, "models/props_lab/huladoll.mdl", entity():pos(), ang(0,0,0))
    holoScale(3, vec(0.1, 0.1, 0.1))
    holoColor(3, vec(200, 150, 50))
    
    for (I = 1, 10) {
        holoCreate(10 + I, "models/props_c17/trappropeller_engine.mdl", entity():pos(), ang(rand(0,360), rand(0,360), rand(0,360)))
        holoScale(10 + I, vec(0.01, 0.01, 0.1))
        holoColor(10 + I, vec(20, 20, 20))
    }
    
    Mode = "Pull"
    IsFiring = 0
    Timer = 0
}

if (ModeButton == 1) {
    if (Mode == "Pull") { Mode = "Push" }
    else { Mode = "Pull" }
    ModeButton = 0
}

if (Button == 1 & IsFiring == 0) {
    IsFiring = 1
    Timer = 0.5
    local AimVec = owner():eyeAngles():forward()
    PortalPos = entity():pos() + AimVec * 250 + vec(0,0,30)
    PortalAng = ang(0, owner():eyeAngles()[2], 0)
}

if (IsFiring == 1 & Timer > 0) {
    Timer = Timer - du()
}

if (IsFiring == 1 & Timer <= 0) {
    holoCreate(4, "models/props_c17/metalGrate01.mdl", PortalPos, PortalAng)
    holoScale(4, vec(0.5, 0.5, 0.1))
    holoColor(4, vec(255, 200, 50))
    
    holoCreate(5, "models/props_c17/canister01a.mdl", PortalPos + vec(0,0,15), ang(0,0,0))
    holoScale(5, vec(0.3, 0.3, 0.2))
    holoColor(5, vec(255, 120, 30))
    
    IsFiring = 0
}

if (exists(holoEntity(4))) { 
    local Dist = owner():pos():dist(PortalPos)
    
    if (Dist < 100) {
        if (Mode == "Pull") {
            owner():setPos(entity():pos() + vec(0,0,50))
            holoColor(4, vec(255, 255, 255))
        }
        if (Mode == "Push") {
            local TargetPos = owner():eyePos() + owner():eyeAngles():forward() * 400
            if (TargetPos:z() > 0) { 
                owner():setPos(TargetPos + vec(0,0,50))
            }
            holoColor(4, vec(255, 255, 255))
        }
        
        holoDelete(4)
        holoDelete(5)
    }
}

local Pressure = math:sin(os:clock() * 10) * 50 + 50
holoCreate(6, "models/hunter/blocks/cube1x1x025.mdl", entity():pos() + vec(0,0,75), ang(0,0,0))
holoScale(6, vec(0.01, 0.01, 0.01))
holoText(6, "Манометр: " + Pressure:toInt() + "%\nРежим: " + Mode, vec(255, 200, 100), 100)

if (IsFiring == 1) {
    holoColor(3, vec(255, 100, 20))
} else {
    holoColor(3, vec(200, 150, 50))
}

ColorR = 200
ColorG = 150
ColorB = 50
