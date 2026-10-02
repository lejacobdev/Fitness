-- CreateTable
CREATE TABLE "WebLogin" (
    "id" TEXT NOT NULL,
    "secretHash" TEXT NOT NULL,
    "device" TEXT,
    "athleteId" TEXT,
    "approvedAt" TIMESTAMP(3),
    "deniedAt" TIMESTAMP(3),
    "claimedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WebLogin_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "WebLogin_expiresAt_idx" ON "WebLogin"("expiresAt");

