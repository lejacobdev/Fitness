-- CreateTable
CREATE TABLE "PartnerSession" (
    "code" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "items" JSONB NOT NULL,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PartnerSession_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "PartnerProgress" (
    "code" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "nickname" TEXT NOT NULL,
    "done" INTEGER NOT NULL DEFAULT 0,
    "total" INTEGER NOT NULL DEFAULT 0,
    "finished" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PartnerProgress_pkey" PRIMARY KEY ("code","athleteId")
);

-- AddForeignKey
ALTER TABLE "PartnerProgress" ADD CONSTRAINT "PartnerProgress_code_fkey" FOREIGN KEY ("code") REFERENCES "PartnerSession"("code") ON DELETE CASCADE ON UPDATE CASCADE;

