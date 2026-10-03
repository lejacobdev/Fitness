-- CreateTable
CREATE TABLE "PushDevice" (
    "token" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "muted" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PushDevice_pkey" PRIMARY KEY ("token")
);

-- CreateIndex
CREATE INDEX "PushDevice_athleteId_idx" ON "PushDevice"("athleteId");

-- AddForeignKey
ALTER TABLE "PushDevice" ADD CONSTRAINT "PushDevice_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;
