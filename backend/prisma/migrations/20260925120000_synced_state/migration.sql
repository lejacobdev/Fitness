-- AlterTable
ALTER TABLE "Athlete" ADD COLUMN "appleRefreshToken" TEXT;

-- CreateTable
CREATE TABLE "SyncedState" (
    "athleteId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SyncedState_pkey" PRIMARY KEY ("athleteId","key")
);

-- AddForeignKey
ALTER TABLE "SyncedState" ADD CONSTRAINT "SyncedState_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;
