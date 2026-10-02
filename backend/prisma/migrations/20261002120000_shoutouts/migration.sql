-- CreateTable
CREATE TABLE "Shoutout" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Shoutout_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Shoutout_athleteId_createdAt_idx" ON "Shoutout"("athleteId", "createdAt");

-- CreateIndex
CREATE INDEX "Shoutout_teamId_athleteId_createdAt_idx" ON "Shoutout"("teamId", "athleteId", "createdAt");

-- AddForeignKey
ALTER TABLE "Shoutout" ADD CONSTRAINT "Shoutout_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shoutout" ADD CONSTRAINT "Shoutout_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

