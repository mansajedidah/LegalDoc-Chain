import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("LegalDoc Chain contract", () => {
    const testDocId = "doc123";
    const testHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const newHash = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";

    it("stores a new document", () => {
      const storeCall = simnet.callPublicFn(
          "LegalDoc-Chain",
          "store-document",
          [
              Cl.stringAscii(testDocId),
              Cl.stringAscii(testHash)
          ],
          wallet1
      );
      expect(storeCall.result).toStrictEqual(Cl.ok(Cl.bool(true)));
  });
  
    it("retrieves stored document", () => {
      // First store the document
      simnet.callPublicFn(
          "LegalDoc-Chain",
          "store-document",
          [
              Cl.stringAscii(testDocId),
              Cl.stringAscii(testHash)
          ],
          wallet1
      );
  
      // Then retrieve it
      const getDocCall = simnet.callReadOnlyFn(
          "LegalDoc-Chain",
          "get-document",
          [Cl.stringAscii(testDocId)],
          wallet1
      );
      
      // The result will be a tuple containing the document data
      const result = getDocCall.result;
      expect(result).toBeDefined();
  });
  

    it("updates existing document", () => {
      // First store the document
      simnet.callPublicFn(
          "LegalDoc-Chain",
          "store-document",
          [
              Cl.stringAscii(testDocId),
              Cl.stringAscii(testHash)
          ],
          wallet1
      );
  
      // Then update it
      const updateCall = simnet.callPublicFn(
          "LegalDoc-Chain",
          "update-document",
          [
              Cl.stringAscii(testDocId),
              Cl.stringAscii(newHash)
          ],
          wallet1
      );
      expect(updateCall.result).toStrictEqual(Cl.ok(Cl.bool(true)));
  });
  

    it("grants access to another user", () => {
      // First store the document
      simnet.callPublicFn(
          "LegalDoc-Chain",
          "store-document",
          [
              Cl.stringAscii(testDocId),
              Cl.stringAscii(testHash)
          ],
          wallet1
      );
  
      // Then grant access
      const grantCall = simnet.callPublicFn(
          "LegalDoc-Chain",
          "grant-access",
          [
              Cl.stringAscii(testDocId),
              Cl.principal(wallet2)
          ],
          wallet1
      );
      expect(grantCall.result).toStrictEqual(Cl.ok(Cl.bool(true)));
  });
  

    it("verifies access permissions", () => {
        const accessCall = simnet.callReadOnlyFn(
            "LegalDoc-Chain",
            "can-access-document",
            [
                Cl.stringAscii(testDocId),
                Cl.principal(wallet2)
            ],
            wallet2
        );
        expect(accessCall.result).toStrictEqual(Cl.bool(false));
    });

    it("prevents unauthorized updates", () => {
        const unauthorizedUpdate = simnet.callPublicFn(
            "LegalDoc-Chain",
            "update-document",
            [
                Cl.stringAscii(testDocId),
                Cl.stringAscii(newHash)
            ],
            wallet2
        );
        expect(unauthorizedUpdate.result).toStrictEqual(Cl.error(Cl.uint(102))); // err-document-not-found
    });
});
