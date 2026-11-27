/** The MO SMS body Applink posts to the receive URL. */
export type SmsMessage = {
  applicationId: string;
  sourceAddress: string;
  message: string;
  requestId: string;
  encoding: string;
};

/** Words that must opt a subscriber out, sent alone or after the routing keyword. */
export const optOutWords = ["STOP", "UNSUB", "OFF"] as const;
const optOut = new Set<string>(optOutWords);

const field = (value: Record<string, unknown>, key: string) =>
  typeof value[key] === "string" ? value[key] as string : "";

/** Reads an MO message, or null when a mandatory field is missing or empty. */
export function parseSmsMessage(input: unknown): SmsMessage | null {
  if (typeof input !== "object" || input === null) return null;
  const value = input as Record<string, unknown>;
  const message = field(value, "message").trim();
  const sourceAddress = field(value, "sourceAddress").trim();
  const requestId = field(value, "requestId").trim();
  const applicationId = field(value, "applicationId").trim();
  if (!message || !sourceAddress || !requestId || !applicationId) return null;
  return { applicationId, sourceAddress, message, requestId, encoding: field(value, "encoding") };
}

/**
 * True when the message asks to stop. The routing keyword is the first word when
 * present, so the command is in the first two; checking both handles `STOP` and
 * `platewise STOP` without hard-coding which keyword the portal assigned.
 */
export function isOptOut(message: string): boolean {
  const words = message.trim().replace(/\s+/g, " ").toUpperCase().split(" ");
  return words.slice(0, 2).some((word) => optOut.has(word.replace(/[^A-Z0-9]/g, "")));
}
