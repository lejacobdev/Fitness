-- Campus leagues
CREATE TABLE "League" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "League_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "League_code_key" ON "League"("code");

CREATE TABLE "LeagueMember" (
    "leagueId" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "nickname" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "LeagueMember_pkey" PRIMARY KEY ("leagueId","athleteId")
);
CREATE INDEX "LeagueMember_athleteId_idx" ON "LeagueMember"("athleteId");
ALTER TABLE "LeagueMember" ADD CONSTRAINT "LeagueMember_leagueId_fkey" FOREIGN KEY ("leagueId") REFERENCES "League"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LeagueMember" ADD CONSTRAINT "LeagueMember_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "WeeklyXP" (
    "athleteId" TEXT NOT NULL,
    "week" TEXT NOT NULL,
    "xp" INTEGER NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "WeeklyXP_pkey" PRIMARY KEY ("athleteId","week")
);
ALTER TABLE "WeeklyXP" ADD CONSTRAINT "WeeklyXP_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Coach teams
CREATE TABLE "Team" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "coachId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Team_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "Team_code_key" ON "Team"("code");
CREATE INDEX "Team_coachId_idx" ON "Team"("coachId");
ALTER TABLE "Team" ADD CONSTRAINT "Team_coachId_fkey" FOREIGN KEY ("coachId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "TeamMember" (
    "teamId" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "nickname" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "TeamMember_pkey" PRIMARY KEY ("teamId","athleteId")
);
CREATE INDEX "TeamMember_athleteId_idx" ON "TeamMember"("athleteId");
ALTER TABLE "TeamMember" ADD CONSTRAINT "TeamMember_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TeamMember" ADD CONSTRAINT "TeamMember_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "Assignment" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "note" TEXT,
    "items" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Assignment_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "Assignment_teamId_date_idx" ON "Assignment"("teamId", "date");
ALTER TABLE "Assignment" ADD CONSTRAINT "Assignment_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Parent weekly summary link
CREATE TABLE "ParentLink" (
    "token" TEXT NOT NULL,
    "athleteId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ParentLink_pkey" PRIMARY KEY ("token")
);
CREATE UNIQUE INDEX "ParentLink_athleteId_key" ON "ParentLink"("athleteId");
ALTER TABLE "ParentLink" ADD CONSTRAINT "ParentLink_athleteId_fkey" FOREIGN KEY ("athleteId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;
