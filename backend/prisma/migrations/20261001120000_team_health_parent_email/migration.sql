-- AlterTable
ALTER TABLE "Team" ADD COLUMN     "trainerCode" TEXT;

-- AlterTable
ALTER TABLE "TeamMember" ADD COLUMN     "shareHealth" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "TeamStaff" (
    "teamId" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'trainer',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TeamStaff_pkey" PRIMARY KEY ("teamId","athleteId")
);

-- CreateTable
CREATE TABLE "Announcement" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Announcement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HealthNote" (
    "id" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "kind" TEXT NOT NULL,
    "areas" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "level" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HealthNote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ParentEmail" (
    "athleteId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "confirmed" BOOLEAN NOT NULL DEFAULT false,
    "confirmMailed" TIMESTAMP(3),
    "lastSentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ParentEmail_pkey" PRIMARY KEY ("athleteId")
);

-- CreateIndex
CREATE INDEX "TeamStaff_athleteId_idx" ON "TeamStaff"("athleteId");

-- CreateIndex
CREATE INDEX "Announcement_teamId_createdAt_idx" ON "Announcement"("teamId", "createdAt");

-- CreateIndex
CREATE INDEX "HealthNote_athleteId_day_idx" ON "HealthNote"("athleteId", "day");

-- CreateIndex
CREATE UNIQUE INDEX "ParentEmail_token_key" ON "ParentEmail"("token");

-- CreateIndex
CREATE UNIQUE INDEX "Team_trainerCode_key" ON "Team"("trainerCode");

-- AddForeignKey
ALTER TABLE "TeamStaff" ADD CONSTRAINT "TeamStaff_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TeamStaff" ADD CONSTRAINT "TeamStaff_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Announcement" ADD CONSTRAINT "Announcement_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HealthNote" ADD CONSTRAINT "HealthNote_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ParentEmail" ADD CONSTRAINT "ParentEmail_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

