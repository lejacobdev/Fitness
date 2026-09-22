-- CreateEnum
CREATE TYPE "UnitSystem" AS ENUM ('METRIC', 'IMPERIAL');

-- CreateEnum
CREATE TYPE "CompetitionKind" AS ENUM ('GAME', 'TOURNAMENT', 'MEET');

-- CreateEnum
CREATE TYPE "SessionSource" AS ENUM ('PHONE', 'WATCH');

-- CreateEnum
CREATE TYPE "ReadinessBand" AS ENUM ('GREEN', 'AMBER', 'RED');

-- CreateTable
CREATE TABLE "Athlete" (
    "id" TEXT NOT NULL,
    "appleUserId" TEXT NOT NULL,
    "displayName" TEXT,
    "birthDate" TIMESTAMP(3) NOT NULL,
    "unitSystem" "UnitSystem" NOT NULL DEFAULT 'METRIC',
    "trainsUnderCoach" BOOLEAN NOT NULL DEFAULT false,
    "equipmentAvailable" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "proUntil" TIMESTAMP(3),
    "originalTransactionId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Athlete_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AthleteSport" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "sportSlug" TEXT NOT NULL,
    "positionSlug" TEXT,
    "seasonStart" TIMESTAMP(3) NOT NULL,
    "seasonEnd" TIMESTAMP(3) NOT NULL,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "AthleteSport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Competition" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "sportSlug" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "kind" "CompetitionKind" NOT NULL,
    "isHome" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,

    CONSTRAINT "Competition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CheckIn" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "sleepQuality" INTEGER NOT NULL,
    "sleepHours" DOUBLE PRECISION,
    "soreness" INTEGER NOT NULL,
    "sorenessAreas" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "energy" INTEGER NOT NULL,
    "stress" INTEGER NOT NULL,
    "readinessBand" "ReadinessBand",
    "readinessZ" DOUBLE PRECISION,
    "clientId" TEXT NOT NULL,

    CONSTRAINT "CheckIn_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Plan" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "weekStart" DATE NOT NULL,
    "phase" TEXT NOT NULL,
    "seed" TEXT NOT NULL,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Plan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlannedSession" (
    "id" TEXT NOT NULL,
    "planId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "focusQualities" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "estimatedMinutes" INTEGER NOT NULL,

    CONSTRAINT "PlannedSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlannedItem" (
    "id" TEXT NOT NULL,
    "plannedSessionId" TEXT NOT NULL,
    "itemSlug" TEXT NOT NULL,
    "order" INTEGER NOT NULL,
    "dose" JSONB NOT NULL,
    "restSec" INTEGER NOT NULL,
    "rationale" TEXT NOT NULL,

    CONSTRAINT "PlannedItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "plannedSessionId" TEXT,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3),
    "sessionRPE" INTEGER,
    "minutes" INTEGER NOT NULL DEFAULT 0,
    "source" "SessionSource" NOT NULL,
    "healthKitWorkoutId" TEXT,
    "notes" TEXT,
    "clientId" TEXT NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SetLog" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "itemSlug" TEXT NOT NULL,
    "setIndex" INTEGER NOT NULL,
    "reps" INTEGER,
    "weightKg" DOUBLE PRECISION,
    "seconds" INTEGER,
    "distanceM" DOUBLE PRECISION,
    "contacts" INTEGER,
    "side" TEXT,
    "clientId" TEXT NOT NULL,

    CONSTRAINT "SetLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SkillBlock" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "sportSlug" TEXT NOT NULL,
    "skillSlug" TEXT NOT NULL,
    "targetDate" DATE NOT NULL,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "seed" TEXT NOT NULL,

    CONSTRAINT "SkillBlock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CoachReport" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "weekStart" DATE NOT NULL,
    "templateSetVersion" INTEGER NOT NULL,
    "headline" TEXT NOT NULL,
    "observations" JSONB NOT NULL,
    "recommendations" JSONB NOT NULL,
    "encouragement" TEXT NOT NULL,
    "templateIndexes" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CoachReport_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Athlete_appleUserId_key" ON "Athlete"("appleUserId");

-- CreateIndex
CREATE UNIQUE INDEX "Athlete_originalTransactionId_key" ON "Athlete"("originalTransactionId");

-- CreateIndex
CREATE INDEX "AthleteSport_athleteId_idx" ON "AthleteSport"("athleteId");

-- CreateIndex
CREATE INDEX "Competition_athleteId_date_idx" ON "Competition"("athleteId", "date");

-- CreateIndex
CREATE INDEX "CheckIn_athleteId_date_idx" ON "CheckIn"("athleteId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "CheckIn_athleteId_date_key" ON "CheckIn"("athleteId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "CheckIn_clientId_key" ON "CheckIn"("clientId");

-- CreateIndex
CREATE INDEX "Plan_athleteId_idx" ON "Plan"("athleteId");

-- CreateIndex
CREATE UNIQUE INDEX "Plan_athleteId_weekStart_key" ON "Plan"("athleteId", "weekStart");

-- CreateIndex
CREATE INDEX "PlannedSession_planId_date_idx" ON "PlannedSession"("planId", "date");

-- CreateIndex
CREATE INDEX "PlannedItem_plannedSessionId_order_idx" ON "PlannedItem"("plannedSessionId", "order");

-- CreateIndex
CREATE INDEX "Session_athleteId_startedAt_idx" ON "Session"("athleteId", "startedAt");

-- CreateIndex
CREATE UNIQUE INDEX "Session_clientId_key" ON "Session"("clientId");

-- CreateIndex
CREATE UNIQUE INDEX "Session_healthKitWorkoutId_key" ON "Session"("healthKitWorkoutId");

-- CreateIndex
CREATE INDEX "SetLog_sessionId_setIndex_idx" ON "SetLog"("sessionId", "setIndex");

-- CreateIndex
CREATE UNIQUE INDEX "SetLog_clientId_key" ON "SetLog"("clientId");

-- CreateIndex
CREATE INDEX "SkillBlock_athleteId_generatedAt_idx" ON "SkillBlock"("athleteId", "generatedAt");

-- CreateIndex
CREATE INDEX "CoachReport_athleteId_idx" ON "CoachReport"("athleteId");

-- CreateIndex
CREATE UNIQUE INDEX "CoachReport_athleteId_weekStart_key" ON "CoachReport"("athleteId", "weekStart");

-- AddForeignKey
ALTER TABLE "AthleteSport" ADD CONSTRAINT "AthleteSport_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Competition" ADD CONSTRAINT "Competition_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckIn" ADD CONSTRAINT "CheckIn_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Plan" ADD CONSTRAINT "Plan_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlannedSession" ADD CONSTRAINT "PlannedSession_planId_fkey" FOREIGN KEY ("planId") REFERENCES "Plan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlannedItem" ADD CONSTRAINT "PlannedItem_plannedSessionId_fkey" FOREIGN KEY ("plannedSessionId") REFERENCES "PlannedSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_plannedSessionId_fkey" FOREIGN KEY ("plannedSessionId") REFERENCES "PlannedSession"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SetLog" ADD CONSTRAINT "SetLog_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SkillBlock" ADD CONSTRAINT "SkillBlock_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachReport" ADD CONSTRAINT "CoachReport_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

