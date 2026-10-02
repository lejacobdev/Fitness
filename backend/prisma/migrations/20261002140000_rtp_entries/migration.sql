-- CreateTable
CREATE TABLE "RtpEntry" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "step" INTEGER NOT NULL,
    "note" TEXT,
    "recordedBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RtpEntry_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RtpEntry_athleteId_createdAt_idx" ON "RtpEntry"("athleteId", "createdAt");

-- CreateIndex
CREATE INDEX "RtpEntry_teamId_athleteId_idx" ON "RtpEntry"("teamId", "athleteId");

-- AddForeignKey
ALTER TABLE "RtpEntry" ADD CONSTRAINT "RtpEntry_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

