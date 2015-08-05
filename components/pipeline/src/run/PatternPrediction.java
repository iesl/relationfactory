package run;

import matcher.*;
import query.QueryList;
import rerac.protos.Corpus.Document;
import util.DocumentExtractor;
import util.Responses;

import java.io.*;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


public class PatternPrediction {
  public static void main(String[] args) throws IOException {
    if (args.length != 2) {
      System.err.println("PatternResponse <sentences.pb> <patterns>");
      return;
    }
    String sentenceFn = args[0];
    String patternsFn = args[1];

    System.err.println("Star pattern matching.");

    Matcher m1 = new CandidateMatcher(0);
    Matcher m2 = new CandidateMatcher(1);
    
    Map<String, List<String>> relToPatterns = 
        new HashMap<String, List<String>>();
        
    BufferedReader br = new BufferedReader(new FileReader(patternsFn));
    for (String line; (line = br.readLine()) != null; ) {
      line = line.trim();
      if (!line.startsWith("#") && !line.isEmpty()) {
        String[] lineParts = line.split("\\s+", 2);
        String rel = lineParts[0];
        String pat = lineParts[1];
        if (!relToPatterns.containsKey(rel)) {
          relToPatterns.put(rel, new ArrayList<String>());
        }
        relToPatterns.get(rel).add(pat);
      }
    }
    br.close();
    
    Map<String, ContextPatternMatcher> relToContextMatcher = 
        new HashMap<String, ContextPatternMatcher>();
    for (String rel : relToPatterns.keySet()) {
        relToContextMatcher.put(rel, 
            new StarContextPatternMatcher(m1, m2, relToPatterns.get(rel)));
    }

    BufferedInputStream is = new BufferedInputStream(new FileInputStream(
        sentenceFn));
    for (Document sentence; 
        (sentence = Document.parseDelimitedFrom(is)) != null;) {
      String rel = DocumentExtractor.relations(sentence).get(0);
      ContextPatternMatcher cpm = relToContextMatcher.get(rel);
      if (null != cpm) {
        List<String> arguments = cpm.arguments(sentence, false);
        for (int argInd = 1; argInd < arguments.size(); argInd += 2) {

          String qid = DocumentExtractor.canonicalArg(sentence, 0, rel);
//          String slot = arguments.get(argInd);
          String slot = DocumentExtractor.canonicalArg(sentence, 1, rel);

          int targetStart = DocumentExtractor.getArgStart(sentence, rel, 0);
          int targetEnd =  DocumentExtractor.getArgEnd(sentence, rel, 0);
          int slotStart = DocumentExtractor.getArgStart(sentence, rel, 1);
          int slotEnd =  DocumentExtractor.getArgEnd(sentence, rel, 1);

          StringBuffer bw = new StringBuffer();
          bw.append(qid).
              append("\t").append(rel).
              append("\t").append(slot).
              append("\t").append(sentence.getId()).
              append("\t").append(Integer.toString(targetStart)).
              append("\t").append(Integer.toString(targetEnd)).
              append("\t").append(Integer.toString(slotStart)).
              append("\t").append(Integer.toString(slotEnd)).
              append("\t").append("1.0");//.
//              append("\n");
          System.out.println(bw.toString());
        }
      }
    }
    is.close();

  }

}
