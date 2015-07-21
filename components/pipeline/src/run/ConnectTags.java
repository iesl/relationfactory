package run;

import util.TextIdentifier;

import java.io.*;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

/**
 * Created by beroth on 7/21/15.
 */
public class ConnectTags {


  static void printConnectedTags(List<String> lines, String sentenceId, int numTokens) {
    System.out.println("<D=" + sentenceId + ">");

    LinkedList<String> tokenTagQueue = new LinkedList<String>();
    String lastTag = "O";

    for (int lineNr = 0; lineNr < lines.size(); lineNr++) {
      String line = lines.get(lineNr);
      String[] lineParts = line.split(" ");

      String fullTag = lineParts[1];
      String tag = fullTag.split("-")[1];

      if (fullTag.startsWith("B-")) {
        String token = lineParts[0];

        if (tag.equals(lastTag) && tokenTagQueue.size() <= numTokens) {
          // Case 1: connect tag spans
          // write out tokens from queue with current label
          for (String qLine: tokenTagQueue) {
            String qToken = qLine.split(" ")[0];
            System.out.println(qToken + " I-" + tag);
          }
          // for current token change B into I
          System.out.println(token + " I-" + tag);
        } else {
          // Case 2: don't connect tag spans
          // write out tokens from Q with original label
          for (String qLine: tokenTagQueue) {
            System.out.println(qLine);
          }
          System.out.println(line);
        }
        // Queue has be written out - empty it.
        tokenTagQueue.clear();
      } else if (fullTag.startsWith("I-")) {
        if (tokenTagQueue.size() > 0) {
          // If tagger did job correctly this should never happen!!! Try to handle illegal tag sequence gracefully...
          System.err.println("Illegal B-I-O tag sequence in sentence: " + sentenceId);
          for (String qLine: tokenTagQueue) {
            System.out.println(qLine);
          }
          tokenTagQueue.clear();
        }

        // Write out tokens with current tag and set last tag to current tag.
        System.out.println(line);
        lastTag = tag;


      } else if (fullTag.equals("O")) {
        // TODO: add token to queue
        tokenTagQueue.addLast(line);
      }
    }
    // don't forget remaining tokens
    for (String qLine: tokenTagQueue) {
      System.out.println(qLine);
    }
    tokenTagQueue.clear();
    System.out.println("</D>");
  }


  public static void main(String[] args) throws IOException {
    if (args.length != 2a) {
      System.err.println("java Candidates <input_dtag> <num_tokens>");
      System.err.println("input_dtag:    Original tagged document");
      System.err.println("num_tokens:    Two spans with the same tag are connected if there are num_tokens or fewer tokens in between.");
      System.err.println("A new tagged document is written to stdout.");
      return;
    }

    String tagFn = args[0];
    int numTokens = Integer.parseInt(args[1]);


    BufferedReader dtagBr = new BufferedReader(new InputStreamReader(new FileInputStream(tagFn), "UTF-8"));

    TextIdentifier docQIdSnr = null;
    List<String> lines = new ArrayList<String>();

    // Stay with the same query as long as the tagged sentences
    // belong to the same document, and sentence numbers are going up.
    // If sentence numbers are not going up, or doc ids change, read the next
    // line of the dscore file and go to the corresponding query.
    for (String line; (line = dtagBr.readLine()) != null; ) {
      if (line.startsWith("<D")) {
        docQIdSnr =
            TextIdentifier.fromDelimited(line.substring(3, line.length() - 1));
      } else if (line.startsWith("</D")) {
        printConnectedTags(lines, docQIdSnr.toValidString(), numTokens);
        docQIdSnr = null;
        lines.clear();
      } else {
        lines.add(line);
      }
    }
    dtagBr.close();
  }
}
