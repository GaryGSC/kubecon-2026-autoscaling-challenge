package demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

    /** Holds a Tomcat worker thread for ms milliseconds (waiting, not CPU). */
    @GetMapping("/")
    public String wait(@RequestParam(required = false) String ms) throws InterruptedException {
        int n;
        try {
            n = Math.max(0, Math.min(30000, Integer.parseInt(ms)));
        } catch (NumberFormatException e) {
            n = 0;
        }
        Thread.sleep(n);
        return "waited " + n + "ms (thread " + Thread.currentThread().getName() + ")\n";
    }
}
