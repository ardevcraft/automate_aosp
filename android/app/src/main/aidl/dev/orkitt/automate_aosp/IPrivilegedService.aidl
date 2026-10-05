
package dev.orkitt.automate_aosp;
interface IPrivilegedService {
    String execute(String action, int value) = 0;
    void destroy() = 16777114;
}
