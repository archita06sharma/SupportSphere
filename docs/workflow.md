# SupportSphere workflow

## Requester
Register → profile → create request → OPEN → assigned → in progress → completed → feedback.

## Volunteer
Register → onboarding (skills, experience, availability) → recommendations → accept → start → complete → history/rating.

## Admin
Login → overview → users → volunteer verification → requests → assignments → feedback.

## Matching
Skill 40 + location 25 + availability 15 + experience 10 + rating 10 = 100. Requests are excluded if the volunteer lacks the required skill, location compatibility or time availability.

## Concurrency
Assignment uses a database transaction and `SELECT status ... FOR UPDATE`, so simultaneous acceptance attempts cannot double-assign the same request.
